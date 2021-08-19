
/* Copyright Airship and Contributors */

#import "UAEventManager+Internal.h"
#import "UAEventStore+Internal.h"
#import "UAEventData+Internal.h"
#import "UAAsyncOperation.h"
#import "UAEvent.h"
#import "UAirship.h"

#if __has_include("AirshipCore/AirshipCore-Swift.h")
#import <AirshipCore/AirshipCore-Swift.h>
#elif __has_include("Airship/Airship-Swift.h")
#import <Airship/Airship-Swift.h>
#endif

@interface UAEventManager()
@property(nonatomic, strong, nonnull) UARuntimeConfig *config;
@property(nonatomic, strong, nonnull) UAPreferenceDataStore *dataStore;
@property(nonatomic, strong, nonnull) UAChannel *channel;
@property(nonatomic, strong, nonnull) UAEventStore *eventStore;
@property(nonatomic, strong, nonnull) UAEventAPIClient *client;
@property(nonatomic, strong, nonnull) NSNotificationCenter *notificationCenter;
@property(nonatomic, strong, nonnull) UAAppStateTracker *appStateTracker;
@property(nonatomic, strong, nonnull) UATaskManager *taskManager;
@property(nonatomic, copy) UADelay * (^delayProvider)(NSTimeInterval);
@property(nonatomic, assign) NSUInteger maxTotalDBSize;
@property(nonatomic, assign) NSUInteger maxBatchSize;
@property(nonatomic, assign) NSUInteger minBatchInterval;
@property(nonatomic, strong, nonnull) NSDate *lastSendTime;
@property(nonatomic, strong, nullable) NSDate *nextUploadDate;
@end

static NSTimeInterval const ForegroundTaskBatchDelay = 1;
static NSTimeInterval const BackgroundTaskBatchDelay = 5;
static NSTimeInterval const EventUploadScheduleDelay = 15;
static NSTimeInterval const BackgroundLowPriorityEventUploadInterval = 900;
static NSString * const UAEventManagerUploadTask = @"UAEventManager.upload";
static NSUInteger const FetchEventLimit = 500;

@implementation UAEventManager

- (instancetype)initWithConfig:(UARuntimeConfig *)config
                     dataStore:(UAPreferenceDataStore *)dataStore
                       channel:(UAChannel *)channel
                    eventStore:(UAEventStore *)eventStore
                        client:(UAEventAPIClient *)client
            notificationCenter:(NSNotificationCenter *)notificationCenter
               appStateTracker:(UAAppStateTracker *)appStateTracker
                   taskManager:(UATaskManager *)taskManager
                 delayProvider:(nonnull UADelay *(^)(NSTimeInterval))delayProvider {

    self = [super init];

    if (self) {
        self.config = config;
        self.eventStore = eventStore;
        self.dataStore = dataStore;
        self.channel = channel;
        self.client = client;
        self.notificationCenter = notificationCenter;
        self.appStateTracker = appStateTracker;
        self.taskManager = taskManager;
        self.delayProvider = delayProvider;

        [self.notificationCenter addObserver:self
                                    selector:@selector(scheduleUpload)
                                        name:UAChannel.channelCreatedEvent
                                      object:nil];

        [self.notificationCenter addObserver:self
                                    selector:@selector(applicationDidEnterBackground)
                                        name:UAAppStateTracker.didEnterBackgroundNotification
                                      object:nil];

        UA_WEAKIFY(self)
        [self.taskManager registerForTaskWithID:UAEventManagerUploadTask
                                     dispatcher:UADispatcher.serial
                                  launchHandler:^(id<UATask> task) {
            UA_STRONGIFY(self)
            [self uploadEventsTask:task];
        }];
    }
    return self;
}

+ (instancetype)eventManagerWithConfig:(UARuntimeConfig *)config
                             dataStore:(UAPreferenceDataStore *)dataStore
                               channel:(UAChannel *)channel {
    UAEventStore *eventStore = [UAEventStore eventStoreWithConfig:config];
    UAEventAPIClient *client = [[UAEventAPIClient alloc] initWithConfig:config];

    UADelay *(^delayProvider)(NSTimeInterval) = ^(NSTimeInterval delay) {
        return [[UADelay alloc] init:delay];
    };

    return [[self alloc] initWithConfig:config
                              dataStore:dataStore
                                channel:channel
                             eventStore:eventStore
                                 client:client
                     notificationCenter:[NSNotificationCenter defaultCenter]
                        appStateTracker:[UAAppStateTracker shared]
                            taskManager:[UATaskManager shared]
                          delayProvider:delayProvider];
}

+ (instancetype)eventManagerWithConfig:(UARuntimeConfig *)config
                             dataStore:(UAPreferenceDataStore *)dataStore
                               channel:(UAChannel *)channel
                            eventStore:(UAEventStore *)eventStore
                                client:(UAEventAPIClient *)client
                    notificationCenter:(NSNotificationCenter *)notificationCenter
                       appStateTracker:(UAAppStateTracker *)appStateTracker
                           taskManager:(UATaskManager *)taskManager
                         delayProvider:(nonnull UADelay *(^)(NSTimeInterval))delayProvider {

    return [[self alloc] initWithConfig:config
                              dataStore:dataStore
                                channel:channel
                             eventStore:eventStore
                                 client:client
                     notificationCenter:notificationCenter
                        appStateTracker:appStateTracker
                            taskManager:taskManager
                          delayProvider:delayProvider];
}

- (void)applicationDidEnterBackground {
    [self scheduleUploadWithDelay:0];
}

#pragma mark -
#pragma mark Preferences

- (NSDate *)lastSendTime {
    return [self.dataStore objectForKey:@"X-UA-Last-Send-Time"] ?: [NSDate distantPast];
}

- (void)setLastSendTime:(NSDate *)lastSendTime {
    if (lastSendTime) {
        [self.dataStore setObject:lastSendTime forKey:@"X-UA-Last-Send-Time"];
    }
}

- (void)updateAnalyticsParametersWithResponse:(UAEventAPIResponse *)response {
    if (response.maxTotalDBSize) {
        self.maxTotalDBSize = (NSUInteger)[response.maxTotalDBSize integerValue] * 1024; //value returned in KB;
    }

    if (response.maxBatchSize) {
        self.maxBatchSize = (NSUInteger)[response.maxBatchSize integerValue] * 1024; //value return in KB
    }

    if (response.minBatchInterval) {
        self.minBatchInterval = (NSUInteger)[response.minBatchInterval integerValue];
    }
}

- (void)setMaxTotalDBSize:(NSUInteger)maxTotalDBSize {
    [self.dataStore setInteger:maxTotalDBSize forKey:kMaxTotalDBSizeUserDefaultsKey];
}

- (NSUInteger)maxTotalDBSize {
    NSUInteger value = (NSUInteger)[self.dataStore integerForKey:kMaxTotalDBSizeUserDefaultsKey];
    value = value == 0 ? kMaxTotalDBSizeBytes : value;
    return [UAEventManager clampValue:value min:kMinTotalDBSizeBytes max:kMaxTotalDBSizeBytes];
}

- (void)setMaxBatchSize:(NSUInteger)maxBatchSize {
    [self.dataStore setInteger:maxBatchSize forKey:kMaxBatchSizeUserDefaultsKey];
}

- (NSUInteger)maxBatchSize {
    NSUInteger value = (NSUInteger)[self.dataStore integerForKey:kMaxBatchSizeUserDefaultsKey];
    value = value == 0 ? kMaxBatchSizeBytes : value;
    return [UAEventManager clampValue:value min:kMinBatchSizeBytes max:kMaxBatchSizeBytes];
}

- (void)setMinBatchInterval:(NSUInteger)minBatchInterval {
    [self.dataStore setInteger:minBatchInterval forKey:kMinBatchIntervalUserDefaultsKey];
}

- (NSUInteger)minBatchInterval {
    NSUInteger value = (NSUInteger)[self.dataStore integerForKey:kMinBatchIntervalUserDefaultsKey];
    return [UAEventManager clampValue:value min:kMinBatchIntervalSeconds max:kMaxBatchIntervalSeconds];
}

#pragma mark -
#pragma mark Events

- (void)addEvent:(id<UAEvent>)event
         eventID:(NSString *)eventID
       eventDate:(NSDate *)eventDate
       sessionID:(NSString *)sessionID {

    [self.eventStore saveEvent:event eventID:eventID eventDate:eventDate sessionID:sessionID];
    [self scheduleUploadWithPriority:event.priority];
}

- (void)deleteAllEvents {
    [self.eventStore deleteAllEvents];
}

- (void)scheduleUpload {
    [self scheduleUploadWithPriority:UAEventPriorityNormal];
}

- (void)scheduleUploadWithPriority:(UAEventPriority)priority {
    switch (priority) {
        case UAEventPriorityHigh:
            [self scheduleUploadWithDelay:0];
            break;

        case UAEventPriorityNormal:
            if (self.appStateTracker.state == UAApplicationStateBackground) {
                [self scheduleUploadWithDelay:0];
            } else {
                [self scheduleUploadWithDelay:[self caculateNextUploadDelay]];
            }
            break;

        case UAEventPriorityLow:
            if (self.appStateTracker.state == UAApplicationStateBackground) {
                NSTimeInterval timeSinceLastSend = [[NSDate date] timeIntervalSinceDate:self.lastSendTime];
                if (timeSinceLastSend < BackgroundLowPriorityEventUploadInterval) {
                    UA_LTRACE("Skipping low priority background event send.");
                    break;
                }
            }

            [self scheduleUploadWithDelay:[self caculateNextUploadDelay]];
            break;
    }
}

- (void)scheduleUploadWithDelay:(NSTimeInterval)delay {
    if (!self.uploadsEnabled) {
        return;
    }

    @synchronized (self) {
        NSDate *uploadDate = [NSDate dateWithTimeIntervalSinceNow:delay];
        if (delay && self.nextUploadDate && [self.nextUploadDate compare:uploadDate] == NSOrderedAscending) {
            UA_LTRACE("Upload already scheduled for an earlier time.");
            return;
        }
        self.nextUploadDate = uploadDate;

        UA_LTRACE("Scheduling upload in %f seconds", delay);
        [self.taskManager enqueueRequestWithID:UAEventManagerUploadTask
                                       options:[UATaskRequestOptions defaultOptions]
                                  initialDelay:delay];
    }
}

- (void)uploadEventsTask:(id<UATask>)task {
    if (!self.uploadsEnabled) {
        @synchronized (self) {
            self.nextUploadDate = nil;
        }
        [task taskCompleted];
        return;
    }

    __block NSTimeInterval batchDelay = ForegroundTaskBatchDelay;

    [UADispatcher.main doSync:^{
        if (self.appStateTracker.state == UAApplicationStateBackground) {
            batchDelay = BackgroundTaskBatchDelay;
        }
    }];

    [self.delayProvider(batchDelay) start];

    @synchronized (self) {
        self.nextUploadDate = nil;
    }

    if (!self.channel.identifier) {
        UA_LTRACE("No Channel ID. Skipping analytic upload.");
        [task taskCompleted];
        return;
    }

    // Clean up store
    [self.eventStore trimEventsToStoreSize:self.maxTotalDBSize];

    NSArray *events = [self prepareEvents];
    if (!events.count) {
        UA_LTRACE(@"Analytic upload finished, no events to upload.");
        [task taskCompleted];
        return;
    }

    NSDictionary *headers = [self prepareHeaders];

    UA_WEAKIFY(self);
    UASemaphore *semaphore = [[UASemaphore alloc] init];
    UADisposable *request = [self.client uploadEvents:events headers:headers completionHandler:^(UAEventAPIResponse * _Nullable response, NSError * _Nullable error) {
        UA_STRONGIFY(self);
        self.lastSendTime = [NSDate date];

        if (error) {
            UA_LTRACE(@"Analytics upload request failed: %@", error);
            [task taskFailed];
        } else {
            if ([response isSuccess]) {
                UA_LTRACE(@"Analytic upload success");
                [self.eventStore deleteEventsWithIDs:[events valueForKey:@"event_id"]];
                [self updateAnalyticsParametersWithResponse:response];
                [task taskCompleted];

                UA_WEAKIFY(self)
                [UADispatcher.main dispatchAsync:^{
                    UA_STRONGIFY(self)
                    [self scheduleUpload];
                }];
            } else {
                UA_LTRACE(@"Analytics upload request failed with status: %lu", (unsigned long)response.status);
                [task taskFailed];
            }
        }

        [semaphore signal];
    }];

    task.expirationHandler = ^{
        [request dispose];
    };

    [semaphore wait];
}

#pragma mark -
#pragma mark Helper methods

- (NSTimeInterval)caculateNextUploadDelay {
    NSTimeInterval delay = 0;
    NSTimeInterval timeSinceLastSend = [[NSDate date] timeIntervalSinceDate:self.lastSendTime];
    if (timeSinceLastSend < self.minBatchInterval) {
        delay = self.minBatchInterval - timeSinceLastSend;
    }
    return MAX(delay, EventUploadScheduleDelay);
}

- (NSDictionary *)prepareHeaders {
    __block NSDictionary *headers = nil;
    [UADispatcher.main doSync:^{
        headers = [self.delegate analyticsHeaders] ?: @{};
    }];
    return headers;
}

- (NSArray *)prepareEvents {
    __block NSMutableArray *preparedEvents = nil;
    UASemaphore *semaphore = [[UASemaphore alloc] init];

    NSUInteger maxBatchSize = self.maxBatchSize;

    [self.eventStore fetchEventsWithLimit:FetchEventLimit completionHandler:^(NSArray<UAEventData *> *result) {
        if (result.count) {
            preparedEvents = [NSMutableArray array];

            NSUInteger batchSize = 0;
            for (UAEventData *eventData in result) {

                if ((batchSize + eventData.bytes.unsignedIntegerValue) > maxBatchSize) {
                    break;
                }

                batchSize += eventData.bytes.unsignedIntegerValue;
                NSMutableDictionary *eventBody = [NSMutableDictionary dictionary];
                [eventBody setValue:eventData.identifier forKey:@"event_id"];
                [eventBody setValue:eventData.time forKey:@"time"];
                [eventBody setValue:eventData.type forKey:@"type"];

                NSError *error = nil;
                NSMutableDictionary *data = [[NSJSONSerialization JSONObjectWithData:eventData.data options:0 error:&error] mutableCopy];
                if (error) {
                    UA_LERR(@"Failed to deserialize event %@: %@", eventData, error);
                    [[eventData managedObjectContext] deleteObject:eventData];
                }

                [data setValue:eventData.sessionID forKey:@"session_id"];
                [eventBody setValue:data forKey:@"data"];

                [preparedEvents addObject:eventBody];
            }
        }

        [semaphore signal];
    }];

    [semaphore wait];
    return preparedEvents;
}

+ (NSUInteger)clampValue:(NSUInteger)value min:(NSUInteger)min max:(NSUInteger)max {
    if (value < min) {
        return min;
    }

    if (value > max) {
        return max;
    }

    return value;
}

@end
