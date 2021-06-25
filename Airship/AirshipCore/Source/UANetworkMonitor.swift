/* Copyright Airship and Contributors */

import Network

/**
 * @note For internal use only. :nodoc:
 */
@objc
open class UANetworkMonitor : NSObject {

    private var pathMonitor: Any?

    @objc
    public var connectionUpdates: ((Bool) -> Void)?

    private var _isConnected = false {
        didSet {
            connectionUpdates?(_isConnected)
        }
    }

    @objc
    open var isConnected: Bool {
        if #available(iOS 12.0, tvOS 12.0, *) {
            return _isConnected
        } else {
            return UAUtils.connectionType() != UAConnectionTypeNone
        }
    }

    @objc
    public override init() {
        super.init()
        if #available(iOS 12.0, tvOS 12.0, *) {
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { path in
                self._isConnected = (path.status == .satisfied)
            }

            monitor.start(queue: DispatchQueue.main)
            self.pathMonitor = monitor
        }
    }
}
