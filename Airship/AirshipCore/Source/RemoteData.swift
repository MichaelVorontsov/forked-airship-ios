/* Copyright Airship and Contributors */

@preconcurrency
import Combine

// NOTE: For internal use only. :nodoc:
final class RemoteData: NSObject, AirshipComponent, RemoteDataProtocol {
    fileprivate enum RefreshStatus: Sendable {
        case none
        case success
        case failed
    }

    static let refreshTaskID = "RemoteData.refresh"
    static let defaultRefreshInterval: TimeInterval = 10
    static let refreshRemoteDataPushPayloadKey = "com.urbanairship.remote-data.update"

    // Datastore keys
    private static let refreshIntervalKey = "remotedata.REFRESH_INTERVAL"
    private static let randomValueKey = "remotedata.randomValue"
    private static let changeTokenKey = "remotedata.CHANGE_TOKEN"

    private let providers: [RemoteDataProviderProtocol]
    private let dataStore: PreferenceDataStore
    private let date: AirshipDateProtocol
    private let localeManager: AirshipLocaleManagerProtocol
    private let workManager: AirshipWorkManagerProtocol
    private let privacyManager: AirshipPrivacyManager
    private let appVersion: String

    private let refreshResultSubject = PassthroughSubject<(source: RemoteDataSource, result: RemoteDataRefreshResult), Never>()
    private let refreshStatusSubjectMap: [RemoteDataSource: CurrentValueSubject<RefreshStatus, Never>]

    private let lastActiveRefreshDate: AirshipMainActorWrapper<Date> = AirshipMainActorWrapper(Date.distantPast)
    private let changeTokenLock: AirshipLock = AirshipLock()
    private let contactSubscription: AirshipUnsafeSendableWrapper<AnyCancellable?> = AirshipUnsafeSendableWrapper(nil)
    private let serialQueue: AsyncSerialQueue = AsyncSerialQueue()

    public var remoteDataRefreshInterval: TimeInterval {
        get {
            let fromStore = self.dataStore.object(
                forKey: RemoteData.refreshIntervalKey
            ) as? TimeInterval
            return fromStore ?? RemoteData.defaultRefreshInterval
        }
        set {
            self.dataStore.setDouble(
                newValue,
                forKey: RemoteData.refreshIntervalKey
            )
        }
    }

    private var randomValue: Int {
        if let value = self.dataStore.object(forKey: RemoteData.randomValueKey) as? Int {
            return value
        }

        let randomValue = Int.random(in: 0...9999)
        self.dataStore.setObject(randomValue, forKey: RemoteData.randomValueKey)
        return randomValue
    }


    private let disableHelper: ComponentDisableHelper



    // NOTE: For internal use only. :nodoc:
    public var isComponentEnabled: Bool {
        get {
            return disableHelper.enabled
        }
        set {
            disableHelper.enabled = newValue
        }
    }

    convenience init(
        config: RuntimeConfig,
        dataStore: PreferenceDataStore,
        localeManager: AirshipLocaleManagerProtocol,
        privacyManager: AirshipPrivacyManager,
        contact: InternalAirshipContactProtocol
    ) {

        let client = RemoteDataAPIClient(config: config)
        self.init(
            dataStore: dataStore,
            localeManager: localeManager,
            privacyManager: privacyManager,
            contact: contact,
            providers: [

                // App
                RemoteDataProvider(
                    dataStore: dataStore,
                    delegate: AppRemoteDataProviderDelegate(
                        config: config,
                        apiClient: client
                    )
                ),

                // Contact
                RemoteDataProvider(
                    dataStore: dataStore,
                    delegate: ContactRemoteDataProviderDelegate(
                        config: config,
                        apiClient: client,
                        contact: contact
                    ),
                    defaultEnabled: false
                )
            ]
        )
    }

    init(
        dataStore: PreferenceDataStore,
        localeManager: AirshipLocaleManagerProtocol,
        privacyManager: AirshipPrivacyManager,
        contact: InternalAirshipContactProtocol,
        providers: [RemoteDataProviderProtocol],
        workManager: AirshipWorkManagerProtocol = AirshipWorkManager.shared,
        date: AirshipDateProtocol = AirshipDate.shared,
        notificationCenter: AirshipNotificationCenter = AirshipNotificationCenter.shared,
        appVersion: String = AirshipUtils.bundleShortVersionString() ?? ""

    ) {
        self.dataStore = dataStore
        self.localeManager = localeManager
        self.privacyManager = privacyManager
        self.providers = providers
        self.workManager = workManager
        self.date = date
        self.appVersion = appVersion

        self.disableHelper = ComponentDisableHelper(
            dataStore: dataStore,
            className: "UARemoteData"
        )

        
        self.refreshStatusSubjectMap = self.providers.reduce(
            into: [RemoteDataSource: CurrentValueSubject<RefreshStatus, Never>]()
        ) {
            $0[$1.source] = CurrentValueSubject(.none)
        }

        super.init()

        self.contactSubscription.value = contact.contactIDUpdates
            .map { $0.contactID }
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.enqueueRefreshTask()
            }

        notificationCenter.addObserver(
            self,
            selector: #selector(enqueueRefreshTask),
            name: AirshipLocaleManager.localeUpdatedEvent,
            object: nil
        )

        notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidForeground),
            name: AppStateTracker.didTransitionToForeground,
            object: nil
        )

        notificationCenter.addObserver(
            self,
            selector: #selector(enqueueRefreshTask),
            name: RuntimeConfig.configUpdatedEvent,
            object: nil
        )

        notificationCenter.addObserver(
            self,
            selector: #selector(enqueueRefreshTask),
            name: AirshipPrivacyManager.changeEvent,
            object: nil
        )
        
        self.workManager.registerWorker(
            RemoteData.refreshTaskID,
            type: .serial
        ) { [weak self] _ in
            return try await self?.handleRefreshTask() ?? .success
        }
    }

    public func setContactSourceEnabled(enabled: Bool) {
        self.serialQueue.enqueue { [providers] in
            let provider = providers.first { $0.source == .contact }
            if (await provider?.setEnabled(enabled) == true) {
                self.enqueueRefreshTask()
            }
        }
    }

    public func status(
        source: RemoteDataSource
    ) async -> RemoteDataSourceStatus {
        for provider in self.providers {
            if (provider.source == source) {
                return await provider.status(
                    changeToken: self.changeToken,
                    locale: self.localeManager.currentLocale,
                    randomeValue: self.randomValue
                )
            }
        }

        return .outOfDate
    }


    public func isCurrent(
        remoteDataInfo: RemoteDataInfo
    ) async -> Bool {
        let locale = localeManager.currentLocale
        for provider in self.providers {
            if (provider.source == remoteDataInfo.source) {
                return await provider.isCurrent(locale: locale, randomeValue: randomValue)
            }
        }

        AirshipLogger.error("No remote data handler for \(remoteDataInfo.source)")
        return false
    }

    public func notifyOutdated(remoteDataInfo: RemoteDataInfo) async {
        for provider in self.providers {
            if (provider.source == remoteDataInfo.source) {
                await provider.notifyOutdated(remoteDataInfo: remoteDataInfo)
                return
            }
        }
    }

    @MainActor
    public func airshipReady() {
        self.enqueueRefreshTask()
    }

    @objc
    @MainActor
    private func applicationDidForeground() {
        let now = self.date.now

        let nextUpdate = self.lastActiveRefreshDate.value.addingTimeInterval(
            self.remoteDataRefreshInterval
        )

        if now >= nextUpdate {
            updateChangeToken()
            self.enqueueRefreshTask()
            self.lastActiveRefreshDate.value = now
        }
    }

    @objc
    private func enqueueRefreshTask() {
        self.refreshStatusSubjectMap.values.forEach { subject in
            subject.send(.none)
        }
        self.workManager.dispatchWorkRequest(
            AirshipWorkRequest(
                workID: RemoteData.refreshTaskID,
                initialDelay: 0,
                requiresNetwork: true,
                conflictPolicy: .replace
            )
        )
    }

    private func updateChangeToken() {
        self.changeTokenLock.sync {
            self.dataStore.setObject(UUID().uuidString, forKey: RemoteData.changeTokenKey)
        }
    }

    /// The change token is just an easy way to know when we need to require an actual update vs checking the remote-data info if it has
    /// changed. We will create a new token on foreground (if its passed the refresh interval) or background push.
    private var changeToken: String {
        var token: String!
        self.changeTokenLock.sync {
            let fromStore = self.dataStore.string(forKey: RemoteData.changeTokenKey)
            if let fromStore = fromStore {
                token = fromStore
            } else {
                token = UUID().uuidString
                self.dataStore.setObject(token, forKey: RemoteData.changeTokenKey)
            }
        }

        return token + self.appVersion
    }
    
    private func handleRefreshTask() async throws -> AirshipWorkResult {
        guard self.privacyManager.isAnyFeatureEnabled() else {
            self.providers.forEach { provider in
                refreshResultSubject.send((provider.source, .skipped))
                refreshStatusSubjectMap[provider.source]?.send(.success)
            }
            return .success
        }

        let changeToken = self.changeToken
        let locale = self.localeManager.currentLocale
        let randomValue = self.randomValue

        let success = await withTaskGroup(
            of: (RemoteDataSource, RemoteDataRefreshResult).self
        ) { [providers, refreshResultSubject, refreshStatusSubjectMap] group in
            for provider in providers {
                group.addTask{
                    let result = await provider.refresh(
                        changeToken: changeToken,
                        locale: locale,
                        randomeValue: randomValue
                    )
                    return (provider.source, result)
                }
            }

            var success: Bool = true
            for await (source, result) in group {
                refreshResultSubject.send((source, result))
                if (result == .failed) {
                    success = false
                    refreshStatusSubjectMap[source]?.send(.failed)
                } else {
                    refreshStatusSubjectMap[source]?.send(.success)
                }
            }

            return success
        }


        return success ? .success : .failure
    }

    @discardableResult
    public func refresh() async -> Bool {
        return await self.refresh(sources: self.providers.map { $0.source})
    }

    @discardableResult
    public func refresh(source: RemoteDataSource) async -> Bool {
        return await self.refresh(sources: [source])
    }

    public func waitRefresh(source: RemoteDataSource) async {
        await waitRefresh(source: source, maxTime: nil)
    }

    public func waitRefresh(
        source: RemoteDataSource,
        maxTime: TimeInterval?
    ) async {
        AirshipLogger.trace("Waiting for remote data to refresh \(source)")
        await waitRefreshStatus(source: source, maxTime: maxTime) { status in
            status != .none
        }
    }

    public func waitRefreshAttempt(source: RemoteDataSource) async {
        await waitRefreshAttempt(source: source, maxTime: nil)
    }

    public func waitRefreshAttempt(
        source: RemoteDataSource,
        maxTime: TimeInterval?
    ) async {
        AirshipLogger.trace("Waiting for remote data to refresh successfully \(source)")
        await waitRefreshStatus(source: source, maxTime: maxTime) { status in
            status != .none
        }
    }

    private func waitRefreshStatus(
        source: RemoteDataSource,
        maxTime: TimeInterval?,
        statusPredicate: @escaping @Sendable (RefreshStatus) -> Bool
    ) async {
        guard let subject = self.refreshStatusSubjectMap[source] else {
            return
        }

        let result: RefreshStatus = await withUnsafeContinuation { continuation in
            var cancellable: AnyCancellable?

            var publisher: AnyPublisher<RefreshStatus, Never> = subject.first(where: statusPredicate).eraseToAnyPublisher()

            if let maxTime = maxTime, maxTime > 0.0 {
                publisher = Publishers.Merge(
                    Just(.none).delay(
                        for: .seconds(maxTime),
                        scheduler: RunLoop.main
                    ),
                    publisher
                ).eraseToAnyPublisher()
            }

            cancellable = publisher.first()
                .sink { result in
                    continuation.resume(returning: result)
                    cancellable?.cancel()
                }
        }

        AirshipLogger.trace("Remote data refresh: \(source), status: \(result)")
    }

    private func refresh(sources: [RemoteDataSource]) async -> Bool {
        // Refresh task will refresh all remoteDataHandlers. If we only care about
        // a subset of the sources, we need filter out those results and collect
        // the expected count of sources.
        var cancellable: AnyCancellable?
        let result = await withCheckedContinuation { continuation in
            cancellable = self.refreshResultSubject
                .filter { result in
                    sources.contains(result.source)
                }
                .collect(sources.count)
                .map { results in
                    !results.contains { result in
                        result.result == .failed
                    }
                }
                .first()
                .sink { result in
                    continuation.resume(returning: result)
                }

            enqueueRefreshTask()
        }
        cancellable?.cancel()
        return result
    }

    public func payloads(types: [String]) async -> [RemoteDataPayload] {
        var payloads: [RemoteDataPayload] = []
        for provider in self.providers {
            payloads += await provider.payloads(types: types)
        }
        return payloads.sortedByType(types)
    }

    private func payloadsFuture(types: [String]) -> Future<[RemoteDataPayload], Never> {
        return Future { promise in
            Task {
                let payloads = await self.payloads(types: types)
                promise(.success(payloads))
            }
        }
    }

    public func publisher(
        types: [String]
    ) -> AnyPublisher<[RemoteDataPayload], Never> {
        // We use the refresh subject to know when to update
        // the current values by listening for a `newData` result
        return self.refreshResultSubject
            .filter { result in
                result.result == .newData
            }
            .flatMap { _ in
                // Fetch data
                self.payloadsFuture(types: types)
            }
            .prepend(
                // Prepend current data
                self.payloadsFuture(types: types)
            )
            .eraseToAnyPublisher()
    }
}

#if !os(watchOS)
extension RemoteData: PushableComponent {
    public func receivedRemoteNotification(
        _ notification: [AnyHashable: Any],
        completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        if notification[RemoteData.refreshRemoteDataPushPayloadKey] == nil {
            completionHandler(.noData)
        } else {
            self.updateChangeToken()
            self.enqueueRefreshTask()
            completionHandler(.newData)
        }
    }
}
#endif


extension Sequence where Iterator.Element : RemoteDataPayload {
    func sortedByType(_ types: [String]) -> [Iterator.Element] {
        return self.sorted { first, second in
            let firstIndex = types.firstIndex(of: first.type) ?? 0
            let secondIndex = types.firstIndex(of: second.type) ?? 0
            return firstIndex < secondIndex
        }
    }
}

