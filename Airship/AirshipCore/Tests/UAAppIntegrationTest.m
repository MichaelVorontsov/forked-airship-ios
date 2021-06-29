/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"

#import "UAAppIntegration+Internal.h"
#import "UANotificationAction.h"
#import "UANotificationCategory.h"
#import "UAPush+Internal.h"
#import "UAAnalytics+Internal.h"
#import "UAActionRunner.h"
#import "UAActionRegistry+Internal.h"
#import "UARuntimeConfig.h"
#import "UANotificationContent.h"
#import "UAirship+Internal.h"
#import "UAPushableComponent.h"

@import AirshipCore;

@interface UAAppIntegrationTest : UAAirshipBaseTest
@property (nonatomic, strong) id mockedApplication;
@property (nonatomic, strong) id mockedUserNotificationCenter;
@property (nonatomic, strong) id mockedAirship;
@property (nonatomic, strong) id mockedAnalytics;
@property (nonatomic, strong) id mockedPush;
@property (nonatomic, strong) id mockedActionRunner;
@property (nonatomic, strong) UAPrivacyManager *privacyManager;

@property (nonatomic, strong) id mockedUNNotificationResponse;
@property (nonatomic, strong) id mockedUANotificationContent;
@property (nonatomic, strong) id mockedUNNotification;
@property (nonatomic, strong) id mockedUNNotificationRequest;
@property (nonatomic, strong) id mockedUNNotificationContent;

@property (nonatomic, copy) NSDictionary *notification;

@end

@implementation UAAppIntegrationTest

- (void)setUp {
    [super setUp];

    self.privacyManager = [[UAPrivacyManager alloc] initWithDataStore:self.dataStore defaultEnabledFeatures:UAFeaturesAll];

    // Set up a mocked application
    self.mockedApplication = [self mockForClass:[UIApplication class]];
    [[[self.mockedApplication stub] andReturn:self.mockedApplication] sharedApplication];

    // Set up mocked User Notification Center
    self.mockedUserNotificationCenter = [self mockForClass:[UNUserNotificationCenter class]];
    [[[self.mockedUserNotificationCenter stub] andReturn:self.mockedUserNotificationCenter] currentNotificationCenter];

    self.mockedActionRunner = [self mockForClass:[UAActionRunner class]];

    self.mockedAnalytics = [self mockForClass:[UAAnalytics class]];
    self.mockedPush = [self mockForClass:[UAPush class]];

    self.mockedAirship = [self mockForClass:[UAirship class]];
    [[[self.mockedAirship stub] andReturn:self.mockedAnalytics] sharedAnalytics];
    [[[self.mockedAirship stub] andReturn:self.mockedPush] push];
    [[[self.mockedAirship stub] andReturn:self.privacyManager] privacyManager];

    [UAirship setSharedAirship:self.mockedAirship];


    self.notification = @{
                          @"aps": @{
                                  @"alert": @"sample alert!",
                                  @"badge": @2,
                                  @"sound": @"cat",
                                  @"category": @"notificationCategory"
                                  },
                          @"com.urbanairship.interactive_actions": @{
                                  @"backgroundIdentifier": @{
                                          @"backgroundAction": @"backgroundActionValue"
                                          },
                                  @"foregroundIdentifier": @{
                                          @"foregroundAction": @"foregroundActionValue",
                                          @"otherForegroundAction": @"otherForegroundActionValue"

                                          },
                                  },
                          @"someActionKey": @"someActionValue"
                          };

    // Mock the nested apple types with unavailable init methods
    self.mockedUANotificationContent = [self mockForClass:[UANotificationContent class]];
    [[[self.mockedUANotificationContent stub] andReturn:self.mockedUANotificationContent] notificationWithUNNotification:OCMOCK_ANY];
    [[[self.mockedUANotificationContent stub] andReturn:self.notification] notificationInfo];

    self.mockedUNNotification = [self mockForClass:[UNNotification class]];
    self.mockedUNNotificationRequest = [self mockForClass:[UNNotificationRequest class]];
    self.mockedUNNotificationContent = [self mockForClass:[UNNotificationContent class]];

    [[[self.mockedUNNotification stub] andReturn:self.mockedUNNotificationRequest] request];
    [[[self.mockedUNNotificationRequest stub] andReturn:self.mockedUNNotificationContent] content];
    [[[self.mockedUNNotificationContent stub] andReturn:self.notification] userInfo];

    self.mockedUNNotificationResponse = [self mockForClass:[UNNotificationResponse class]];
    [[[self.mockedUNNotificationResponse stub] andReturn:self.mockedUNNotification] notification];
}

- (void)tearDown {
    [self.mockedUANotificationContent stopMocking];
    [self.mockedUNNotification stopMocking];
    [self.mockedUserNotificationCenter stopMocking];
    [self.mockedUNNotificationContent stopMocking];
    [self.mockedUNNotificationRequest stopMocking];
    [self.mockedUNNotificationResponse stopMocking];
    [super tearDown];
}

/**
 * Test registering a device token.
 */
- (void)testRegisteredDeviceToken {
    NSData *token = [@"some-token" dataUsingEncoding:NSASCIIStringEncoding];

    // Expect analytics to receive a UADeviceRegistrationEvent event
    [[self.mockedAnalytics expect] addEvent:[OCMArg checkWithBlock:^BOOL(id obj) {
        return [obj isKindOfClass:[UADeviceRegistrationEvent class]];
    }]];

    // Expect UAPush to receive the device token
    [[self.mockedPush expect] application:self.mockedApplication didRegisterForRemoteNotificationsWithDeviceToken:token];

    // Call the app integration
    [UAAppIntegration application:self.mockedApplication didRegisterForRemoteNotificationsWithDeviceToken:token];

    // Verify everything
    [self.mockedAnalytics verify];
    [self.mockedPush verify];
}

/**
 * Test application:didFailToRegisterForRemoteNotificationsWithError .
 */
- (void)testFailedToRegisteredDeviceToken {
    NSError *error = [NSError errorWithDomain:@"domain" code:100 userInfo:nil];
    
    // Expect UAPush method to be called
    [[self.mockedPush expect] application:self.mockedApplication didFailToRegisterForRemoteNotificationsWithError:error];
    
    // Call the app integration
    [UAAppIntegration application:self.mockedApplication didFailToRegisterForRemoteNotificationsWithError:error];
    
    // Verify everything
    [self.mockedPush verify];
}

/**
 * Test userNotificationCenter:willPresentNotification:withCompletionHandler when automatic setup is enabled
 */
- (void)testWillPresentNotificationAutomaticSetupEnabled {

    __block BOOL completionHandlerCalled = NO;

    // Mock UARuntimeConfig instance to so we can return a mocked automatic setup
    id mockConfig = [self strictMockForClass:[UARuntimeConfig class]];
    [[[self.mockedAirship stub] andReturn:mockConfig] config];

    //Mock automatic setup to be enabled
    [[[mockConfig stub] andReturnValue:OCMOCK_VALUE(YES)] isAutomaticSetupEnabled];

    // Assume alert option
    UNNotificationPresentationOptions expectedOptions = UNNotificationPresentationOptionAlert;
    
    if (@available(iOS 14.0, *)) {
        expectedOptions = UNNotificationPresentationOptionList | UNNotificationPresentationOptionBanner;
    }

    // Return expected options from presentationOptionsForNotification
    [[[self.mockedPush stub] andReturnValue:OCMOCK_VALUE(expectedOptions)] presentationOptionsForNotification:OCMOCK_ANY];

    // Reject any calls to UAActionRunner when automatic setup is enabled
    [[[self.mockedActionRunner reject] ignoringNonObjectArgs] runActionsWithActionValues:OCMOCK_ANY
                                                                               situation:0
                                                                                metadata:OCMOCK_ANY
                                                                       completionHandler:OCMOCK_ANY];

    // Reject any calls to UAPush when automatic setup is enabled
    [[self.mockedPush reject] handleRemoteNotification:OCMOCK_ANY foreground:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    // Call the integration
    [UAAppIntegration userNotificationCenter:self.mockedUserNotificationCenter
                     willPresentNotification:self.mockedUNNotification
                       withCompletionHandler:^(UNNotificationPresentationOptions options) {
                           completionHandlerCalled = YES;
                           // Check that completion handler is called with expected options
                           XCTAssertEqual(options, expectedOptions);
                       }];

    // Verify everything
    [self.mockedActionRunner verify];
    [self.mockedPush verify];
    XCTAssertTrue(completionHandlerCalled, @"Completion handler should be called.");
}

/**
 * Test userNotificationCenter:willPresentNotification:withCompletionHandler when automatic setup is disabled
 */
- (void)testWillPresentNotificationAutomaticSetupDisabled {

    BOOL (^handlerCheck)(id obj) = ^(id obj) {
        void (^handler)(UAActionResult *) = obj;
        if (handler) {
            handler([UAActionResult emptyResult]);
        }
        return YES;
    };

    // Mock UARuntimeConfig instance to so we can return a mocked automatic setup
    id mockConfig = [self strictMockForClass:[UARuntimeConfig class]];
    [[[self.mockedAirship stub] andReturn:mockConfig] config];
    UNNotificationPresentationOptions expectedOptions = UNNotificationPresentationOptionAlert;
    
    if (@available(iOS 14.0, *)) {
        expectedOptions = UNNotificationPresentationOptionList | UNNotificationPresentationOptionBanner;
    }

    //Mock automatic setup to be disabled
    [[[mockConfig stub] andReturnValue:OCMOCK_VALUE(NO)] isAutomaticSetupEnabled];

    //Expect UAPush call to presentationOptionsForNotification with the specified notification
    [[[self.mockedPush stub] andReturnValue:OCMOCK_VALUE(expectedOptions)] presentationOptionsForNotification:self.mockedUNNotification];

    NSDictionary *expectedMetadata = @{ UAActionMetadataForegroundPresentationKey: @((expectedOptions & UNNotificationPresentationOptionAlert) > 0),
                                        UAActionMetadataPushPayloadKey: self.notification };
    
    if (@available(iOS 14.0, *)) {
        expectedMetadata = @{ UAActionMetadataForegroundPresentationKey: @((expectedOptions & (UNNotificationPresentationOptionList | UNNotificationPresentationOptionBanner)) > 0),
                              UAActionMetadataPushPayloadKey: self.notification };
    }

    UASituation expectedSituation = UASituationForegroundPush;

    [[self.mockedActionRunner expect] runActionsWithActionValues:self.notification
                                                       situation:expectedSituation
                                                        metadata:expectedMetadata
                                               completionHandler:[OCMArg checkWithBlock:handlerCheck]];

    // Expect UAPush to be called when automatic setup is enabled
    [[self.mockedPush expect] handleRemoteNotification:[OCMArg checkWithBlock:^BOOL(id obj) {
        UANotificationContent *content = obj;
        return [content.notificationInfo isEqualToDictionary:self.notification];
    }] foreground:YES completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^handler)(UIBackgroundFetchResult) = obj;
        handler(UIBackgroundFetchResultNewData);
        return YES;
    }]];

    // Call the integration
    XCTestExpectation *handlerExpectation = [self expectationWithDescription:@"Completion handler called"];
    [UAAppIntegration userNotificationCenter:self.mockedUserNotificationCenter
                     willPresentNotification:self.mockedUNNotification
                       withCompletionHandler:^(UNNotificationPresentationOptions options) {
                           [handlerExpectation fulfill];
                           // Check that completion handler is called with expected options
                           XCTAssertEqual(options, expectedOptions);
                       }];

    [self waitForTestExpectations];
    
    // Verify everything
    [self.mockedActionRunner verify];
    [self.mockedPush verify];
}

/**
 * Tests userNotificationCenter:didReceiveNotificationResponse:completionHandler when
 * launched from push
 */
-(void)testDidReceiveNotificationResponseWithDefaultAction {

    __block BOOL completionHandlerCalled = NO;

    BOOL (^handlerCheck)(id obj) = ^(id obj) {
        completionHandlerCalled = YES;

        void (^handler)(UAActionResult *) = obj;
        if (handler) {
            handler([UAActionResult emptyResult]);
        }
        return YES;
    };

    // Mock the action idetifier to return UNNotificationDefaultActionIdentifier
    [[[self.mockedUNNotificationResponse stub] andReturn:UNNotificationDefaultActionIdentifier] actionIdentifier];

    // Default action is launched from push
    UASituation expectedSituation = UASituationLaunchedFromPush;

    NSDictionary *expectedMetadata = @{ UAActionMetadataPushPayloadKey:self.notification,
                                        UAActionMetadataUserNotificationActionIDKey:UNNotificationDefaultActionIdentifier};

    // Expect a call to UAActionRunner
    [[self.mockedActionRunner expect] runActionsWithActionValues:self.notification
                                                       situation:expectedSituation
                                                        metadata:expectedMetadata
                                               completionHandler:[OCMArg checkWithBlock:handlerCheck]];

    // Expect a call to UAPush
    [[self.mockedPush expect] handleNotificationResponse:[OCMArg checkWithBlock:^BOOL(id obj) {
        UANotificationResponse *response = obj;
        return [response.actionIdentifier isEqualToString:UANotificationDefaultActionIdentifier] &&
        [response.notificationContent.notificationInfo isEqualToDictionary:self.notification];
    }] completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^handler)(void) = obj;
        handler();
        return YES;
    }]];

    // Expect a call to UAAnalytics
    [[self.mockedAnalytics expect] launchedFromNotification:self.notification];

    // Call the integration
    [UAAppIntegration userNotificationCenter:self.mockedUserNotificationCenter
              didReceiveNotificationResponse:self.mockedUNNotificationResponse
                       withCompletionHandler:^{
                           completionHandlerCalled = YES;
                       }];

    // Verify everything
    [self.mockedActionRunner verify];
    [self.mockedPush verify];
    XCTAssertTrue(completionHandlerCalled, @"Completion handler should be called.");
}

/**
 * Tests userNotificationCenter:didReceiveNotificationResponse:completionHandler
 * with a foreground action
 */
-(void)testDidReceiveNotificationResponseWithForegroundAction {
    BOOL (^handlerCheck)(id obj) = ^(id obj) {
        void (^handler)(UAActionResult *) = obj;
        if (handler) {
            handler([UAActionResult emptyResult]);
        }
        return YES;
    };

    UASituation expectedSituation = UASituationForegroundInteractiveButton;

    [[[self.mockedUNNotificationResponse stub] andReturn:@"foregroundIdentifier"] actionIdentifier];
    [[[self.mockedUANotificationContent stub] andReturn:@"notificationCategory"] categoryIdentifier];

    UANotificationAction *foregroundAction = [UANotificationAction actionWithIdentifier:@"foregroundIdentifier"
                                                                                  title:@"title"
                                                                                options:(UANotificationActionOptions)UNNotificationActionOptionForeground];

    UANotificationCategory *category = [UANotificationCategory categoryWithIdentifier:@"notificationCategory"
                                                                              actions:@[foregroundAction]
                                                                    intentIdentifiers:@[]
                                                                              options:0];

    [[[self.mockedPush stub] andReturn:[NSSet setWithArray:@[category]]] combinedCategories];

    UANotificationResponse *expectedAirshipResponse = [UANotificationResponse notificationResponseWithUNNotificationResponse:self.mockedUNNotificationResponse];
    NSMutableDictionary *expectedMetadata = [NSMutableDictionary dictionary];
    [expectedMetadata setValue:[expectedAirshipResponse actionIdentifier] forKey:UAActionMetadataUserNotificationActionIDKey];
    [expectedMetadata setValue:expectedAirshipResponse.notificationContent.notificationInfo forKey:UAActionMetadataPushPayloadKey];
    [expectedMetadata setValue:expectedAirshipResponse.responseText forKey:UAActionMetadataResponseInfoKey];

    // Expect a call to UAActionRunner
    [[self.mockedActionRunner expect] runActionsWithActionValues:self.notification[@"com.urbanairship.interactive_actions"][@"foregroundIdentifier"]
                                                       situation:expectedSituation
                                                        metadata:expectedMetadata
                                               completionHandler:[OCMArg checkWithBlock:handlerCheck]];



    // Expect a call to UAAnalytics
    [[self.mockedAnalytics expect] launchedFromNotification:self.notification];
    [[self.mockedAnalytics expect] addEvent:[OCMArg checkWithBlock:^BOOL(id obj) {
        return [obj isKindOfClass:[UAInteractiveNotificationEvent class]];
    }]];

    // Expect a call to UAPush
    [[self.mockedPush expect] handleNotificationResponse:[OCMArg checkWithBlock:^BOOL(id obj) {
        UANotificationResponse *response = obj;
        return [response.actionIdentifier isEqualToString:@"foregroundIdentifier"] &&
        [response.notificationContent.notificationInfo isEqualToDictionary:self.notification];
    }] completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^handler)(void) = obj;
        handler();
        return YES;
    }]];

    // Call the integration
    XCTestExpectation *testExpectation = [self expectationWithDescription:@"completion handler called"];
    [UAAppIntegration userNotificationCenter:self.mockedUserNotificationCenter
              didReceiveNotificationResponse:self.mockedUNNotificationResponse
                       withCompletionHandler:^{
                           [testExpectation fulfill];
                       }];
    [self waitForTestExpectations];

    // Verify everything
    [self.mockedActionRunner verify];
    [self.mockedPush verify];
    [self.mockedAnalytics verify];
}

/**
 * Tests userNotificationCenter:didReceiveNotificationResponse:completionHandler
 * with a background action
 */
-(void)testDidReceiveNotificationResponseWithBackgroundAction {
    BOOL (^handlerCheck)(id obj) = ^(id obj) {
        void (^handler)(UAActionResult *) = obj;
        if (handler) {
            handler([UAActionResult emptyResult]);
        }
        return YES;
    };

    UASituation expectedSituation = UASituationForegroundInteractiveButton;
    [[[self.mockedUNNotificationResponse stub] andReturn:@"backgroundIdentifier"] actionIdentifier];
    [[[self.mockedUANotificationContent stub] andReturn:@"notificationCategory"] categoryIdentifier];

    UANotificationAction *foregroundAction = [UANotificationAction actionWithIdentifier:@"backgroundIdentifier"
                                                                                  title:@"title"
                                                                                options:(UANotificationActionOptions)UNNotificationActionOptionForeground];

    UANotificationCategory *category = [UANotificationCategory categoryWithIdentifier:@"notificationCategory"
                                                                              actions:@[foregroundAction]
                                                                    intentIdentifiers:@[]
                                                                              options:0];

    [[[self.mockedPush stub] andReturn:[NSSet setWithArray:@[category]]] combinedCategories];

    UANotificationResponse *expectedAirshipResponse = [UANotificationResponse notificationResponseWithUNNotificationResponse:self.mockedUNNotificationResponse];
    NSMutableDictionary *expectedMetadata = [NSMutableDictionary dictionary];
    [expectedMetadata setValue:[expectedAirshipResponse actionIdentifier] forKey:UAActionMetadataUserNotificationActionIDKey];
    [expectedMetadata setValue:expectedAirshipResponse.notificationContent.notificationInfo forKey:UAActionMetadataPushPayloadKey];
    [expectedMetadata setValue:expectedAirshipResponse.responseText forKey:UAActionMetadataResponseInfoKey];

    // Expect a call to UAActionRunner
    [[self.mockedActionRunner expect] runActionsWithActionValues:self.notification[@"com.urbanairship.interactive_actions"][@"backgroundIdentifier"]
                                                       situation:expectedSituation
                                                        metadata:expectedMetadata
                                               completionHandler:[OCMArg checkWithBlock:handlerCheck]];

    // Expect a call to UAAnalytics
    [[self.mockedAnalytics expect] addEvent:[OCMArg checkWithBlock:^BOOL(id obj) {
        return [obj isKindOfClass:[UAInteractiveNotificationEvent class]];
    }]];

    // Expect a call to UAPush
    [[self.mockedPush expect] handleNotificationResponse:[OCMArg checkWithBlock:^BOOL(id obj) {
        UANotificationResponse *response = obj;
        return [response.actionIdentifier isEqualToString:@"backgroundIdentifier"] &&
        [response.notificationContent.notificationInfo isEqualToDictionary:self.notification];
    }] completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^handler)(void) = obj;
        handler();
        return YES;
    }]];

    // Call the integration
    XCTestExpectation *testExpectation = [self expectationWithDescription:@"completion handler called"];
    [UAAppIntegration userNotificationCenter:self.mockedUserNotificationCenter
              didReceiveNotificationResponse:self.mockedUNNotificationResponse
                       withCompletionHandler:^{
                           [testExpectation fulfill];
                       }];
    [self waitForTestExpectations];

    // Verify everything
    [self.mockedActionRunner verify];
    [self.mockedPush verify];
    [self.mockedAnalytics verify];
}

/**
 * Tests userNotificationCenter:didReceiveNotificationResponse:completionHandler with
 * an unknown action
 */
-(void)testDidReceiveNotificationResponseUnknownAction {
    [[[self.mockedUNNotificationResponse stub] andReturn:@"testActionIdentifier"] actionIdentifier];
    [[[self.mockedUNNotificationContent stub] andReturn:@"some_unknown_category"] categoryIdentifier];

    // Expect the UAPush to be called
    [[self.mockedPush expect] handleNotificationResponse:[OCMArg checkWithBlock:^BOOL(id obj) {
        UANotificationResponse *response = obj;
        return [response.actionIdentifier isEqualToString:@"testActionIdentifier"] &&
        [response.notificationContent.notificationInfo isEqualToDictionary:self.notification];
    }] completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^handler)(void) = obj;
        handler();
        return YES;
    }]];

    // Call the integration
    XCTestExpectation *testExpectation = [self expectationWithDescription:@"completion handler called"];
    [UAAppIntegration userNotificationCenter:self.mockedUserNotificationCenter
              didReceiveNotificationResponse:self.mockedUNNotificationResponse
                       withCompletionHandler:^{
                           [testExpectation fulfill];
                       }];

    [self waitForTestExpectations];

    // Verify everything
    [self.mockedPush verify];
}

/**
 * Test application:didReceiveRemoteNotification:fetchCompletionHandler in the
 * background when a message ID is present.
 */
- (void)testReceivedRemoteNotificationBackgroundWithMessageID {

    // Notification modified to include message ID
    self.notification = @{
                          @"aps": @{
                                  @"alert": @"sample alert!",
                                  @"badge": @2,
                                  @"sound": @"cat",
                                  @"category": @"notificationCategory"
                                  },
                          @"com.urbanairship.interactive_actions": @{
                                  @"backgroundIdentifier": @{
                                          @"backgroundAction": @"backgroundActionValue"
                                          },
                                  @"foregroundIdentifier": @{
                                          @"foregroundAction": @"foregroundActionValue",
                                          @"otherForegroundAction": @"otherForegroundActionValue"

                                          },
                                  },
                          @"someActionKey": @"someActionValue",
                          @"_uamid": @"rich push ID"
                          };

    XCTestExpectation *handlerExpectation = [self expectationWithDescription:@"Completion handler called"];

    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateBackground)] applicationState];

    __block BOOL completionHandlerCalled = NO;
    BOOL (^handlerCheck)(id obj) = ^(id obj) {
        void (^handler)(UAActionResult *) = obj;
        if (handler) {
            UAActionResult *testResult = [UAActionResult resultWithValue:@"test" withFetchResult:UAActionFetchResultNewData];
            handler(testResult);
        }
        return YES;
    };

    NSDictionary *expectedMetadata = @{ UAActionMetadataForegroundPresentationKey: @(NO),
                                        UAActionMetadataPushPayloadKey: self.notification};

    NSDictionary *actionsPayload = [UAAppIntegration actionsPayloadForNotificationContent:
                                    [UANotificationContent notificationWithNotificationInfo:self.notification] actionIdentifier:nil];

    // Expect actions to be run for the action identifier
    [[self.mockedActionRunner expect] runActionsWithActionValues:actionsPayload
                                                       situation:UASituationBackgroundPush
                                                        metadata:expectedMetadata
                                               completionHandler:[OCMArg checkWithBlock:handlerCheck]];

    // Expect the UAPush to be called
    [[self.mockedPush expect] handleRemoteNotification:[OCMArg checkWithBlock:^BOOL(id obj) {
        UANotificationContent *content = obj;
        return [content.notificationInfo isEqualToDictionary:self.notification];
    }] foreground:NO completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^handler)(UIBackgroundFetchResult) = obj;
        handler(UIBackgroundFetchResultNewData);
        return YES;
    }]];

    // Call the integration
    [UAAppIntegration application:self.mockedApplication
     didReceiveRemoteNotification:self.notification
           fetchCompletionHandler:^(UIBackgroundFetchResult result) {
               completionHandlerCalled = YES;
               XCTAssertEqual(result, UIBackgroundFetchResultNewData);
               [handlerExpectation fulfill];
           }];

    // Verify everything
    [self waitForTestExpectations];
    [self.mockedActionRunner verify];
    [self.mockedPush verify];

    XCTAssertTrue(completionHandlerCalled, @"Completion handler should be called.");
}

/**
 * Test application:didReceiveRemoteNotification:fetchCompletionHandler in the
 * background when a message ID is not present.
 */
- (void)testReceivedRemoteNotificationBackgroundNoMessageID {

    XCTestExpectation *handlerExpectation = [self expectationWithDescription:@"Completion handler called"];

    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateBackground)] applicationState];

    __block BOOL completionHandlerCalled = NO;
    BOOL (^handlerCheck)(id obj) = ^(id obj) {
        void (^handler)(UAActionResult *) = obj;
        if (handler) {
            UAActionResult *testResult = [UAActionResult resultWithValue:@"test" withFetchResult:UAActionFetchResultNewData];
            handler(testResult);
        }
        return YES;
    };

    NSDictionary *expectedMetadata = @{ UAActionMetadataForegroundPresentationKey: @(NO),
                                        UAActionMetadataPushPayloadKey: self.notification};

    NSDictionary *actionsPayload = [UAAppIntegration actionsPayloadForNotificationContent:
                                    [UANotificationContent notificationWithNotificationInfo:self.notification] actionIdentifier:nil];

    // Expect actions to be run for the action identifier
    [[self.mockedActionRunner expect] runActionsWithActionValues:actionsPayload
                                                       situation:UASituationBackgroundPush
                                                        metadata:expectedMetadata
                                               completionHandler:[OCMArg checkWithBlock:handlerCheck]];

    // Expect the UAPush to be called
    [[self.mockedPush expect] handleRemoteNotification:[OCMArg checkWithBlock:^BOOL(id obj) {
        UANotificationContent *content = obj;
        return [content.notificationInfo isEqualToDictionary:self.notification];
    }] foreground:NO completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^handler)(UIBackgroundFetchResult) = obj;
        handler(UIBackgroundFetchResultNewData);
        return YES;
    }]];

    // Call the integration
    [UAAppIntegration application:self.mockedApplication
     didReceiveRemoteNotification:self.notification
           fetchCompletionHandler:^(UIBackgroundFetchResult result) {
               completionHandlerCalled = YES;
               XCTAssertEqual(result, UIBackgroundFetchResultNewData);
               [handlerExpectation fulfill];
           }];

    // Verify everything
    [self waitForTestExpectations];
    [self.mockedActionRunner verify];
    [self.mockedPush verify];

    XCTAssertTrue(completionHandlerCalled, @"Completion handler should be called.");
}

/**
 * Test application:didReceiveRemoteNotification:fetchCompletionHandler when
 * it's launching the application treats it as a default notification response.
 */
- (void)testReceivedRemoteNotificationLaunch {
    XCTestExpectation *handlerExpectation = [self expectationWithDescription:@"Completion handler called"];

    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateInactive)] applicationState];

    __block BOOL completionHandlerCalled = NO;
    BOOL (^handlerCheck)(id obj) = ^(id obj) {
        void (^handler)(UAActionResult *) = obj;
        if (handler) {
            handler([UAActionResult emptyResult]);
        }
        return YES;
    };

    NSDictionary *expectedMetadata = @{UAActionMetadataPushPayloadKey:self.notification,
                                       UAActionMetadataForegroundPresentationKey:@0};

    // Expect UAActionRunner to be called with actions to be run for the action identifier
    [[self.mockedActionRunner expect] runActionsWithActionValues:self.notification
                                                       situation:UASituationBackgroundPush
                                                        metadata:expectedMetadata
                                               completionHandler:[OCMArg checkWithBlock:handlerCheck]];


    // Expect UAPush to be called
    [[self.mockedPush expect] handleRemoteNotification:[OCMArg checkWithBlock:^BOOL(id obj) {
        UANotificationContent *content = obj;
        return [content.notificationInfo isEqualToDictionary:self.notification];
    }] foreground:NO completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^handler)(UIBackgroundFetchResult) = obj;
        handler(UIBackgroundFetchResultNewData);
        return YES;
    }]];

    // Call the integration
    [UAAppIntegration application:self.mockedApplication
     didReceiveRemoteNotification:self.notification
           fetchCompletionHandler:^(UIBackgroundFetchResult result) {
               completionHandlerCalled = YES;
               XCTAssertEqual(result, UIBackgroundFetchResultNewData);
               [handlerExpectation fulfill];
           }];

    // Verify everything
    //[self.mockedActionRunner verify];
    [self.mockedPush verify];
    [self waitForTestExpectations];
    XCTAssertTrue(completionHandlerCalled, @"Completion handler should be called.");
}

/**
 * Test background app refresh results in a call to update authorized notification types
 */
- (void)testDidReceiveBackgroundAppRefresh {
    __block BOOL handlerCalled = false;

    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateBackground)] applicationState];
    [[self.mockedPush expect] updateAuthorizedNotificationTypes];

    [UAAppIntegration application:self.mockedApplication performFetchWithCompletionHandler:^(UIBackgroundFetchResult result) {
        handlerCalled = true;
    }];

    [self.mockedPush verify];
    XCTAssertTrue(handlerCalled);
}

- (void)expectRunActionsWithActionValues:(NSMutableDictionary *)expectedActionPayload {
    XCTestExpectation *runActionsExpectation = [self expectationWithDescription:@"runActionsWithActionValues should be called"];
    [[[self.mockedActionRunner expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:5];
        UAActionCompletionHandler completionHandler = (__bridge UAActionCompletionHandler)arg;
        completionHandler([UAActionResult resultWithValue:nil]);
        [runActionsExpectation fulfill];
    }] runActionsWithActionValues:expectedActionPayload
                        situation:UASituationBackgroundPush
                         metadata:OCMOCK_ANY
                completionHandler:OCMOCK_ANY];
}

/**
 * Test notifying all pushable components of the response.
 */
-(void)testFanOutResponseToPushableComponents {
    id pushable = [self mockForProtocol:@protocol(UAPushableComponent)];
    [[[self.mockedAirship stub] andReturn:@[pushable]] components];

    [[pushable expect] receivedNotificationResponse:[OCMArg checkWithBlock:^BOOL(id obj) {
        UANotificationResponse *response = obj;
        return response.response == self.mockedUNNotificationResponse;
    }] completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^handler)(void) = obj;
        handler();
        return YES;
    }]];

    // Expect the UAPush to be called
    [[self.mockedPush expect] handleNotificationResponse:OCMOCK_ANY completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^handler)(void) = obj;
        handler();
        return YES;
    }]];

    // Call the integration
    XCTestExpectation *testExpectation = [self expectationWithDescription:@"completion handler called"];
    [UAAppIntegration userNotificationCenter:self.mockedUserNotificationCenter
              didReceiveNotificationResponse:self.mockedUNNotificationResponse
                       withCompletionHandler:^{
                           [testExpectation fulfill];
                       }];

    [self waitForTestExpectations];

    // Verify everything
    [self.mockedPush verify];
    [pushable verify];
}

/**
 * Test notifying all pushable components of the remote notification.
 */
- (void)testFanOutRemoteNotificationToPushableComponents {
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateBackground)] applicationState];

    id pushable = [self mockForProtocol:@protocol(UAPushableComponent)];
    [[[self.mockedAirship stub] andReturn:@[pushable]] components];

    [[pushable expect] receivedRemoteNotification:[OCMArg checkWithBlock:^BOOL(id obj) {
        UANotificationContent *content = obj;
        return [content.notificationInfo isEqualToDictionary:self.notification];
    }] completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^handler)(UIBackgroundFetchResult) = obj;
        handler(UIBackgroundFetchResultNewData);
        return YES;
    }]];

    // Expect UAActionRunner to be called with actions to be run for the action identifier
    [[self.mockedActionRunner expect] runActionsWithActionValues:self.notification
                                                       situation:UASituationBackgroundPush
                                                        metadata:OCMOCK_ANY
                                               completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
                                                    void (^handler)(UAActionResult *) = obj;
                                                    handler([UAActionResult emptyResult]);
                                                    return YES;
                                               }]];

    // Expect UAPush to be called
    [[self.mockedPush expect] handleRemoteNotification:[OCMArg checkWithBlock:^BOOL(id obj) {
        UANotificationContent *content = obj;
        return [content.notificationInfo isEqualToDictionary:self.notification];
    }] foreground:NO completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^handler)(UIBackgroundFetchResult) = obj;
        handler(UIBackgroundFetchResultNoData);
        return YES;
    }]];

    // Call the integration
    XCTestExpectation *handlerExpectation = [self expectationWithDescription:@"Completion handler called"];
    [UAAppIntegration application:self.mockedApplication
     didReceiveRemoteNotification:self.notification
           fetchCompletionHandler:^(UIBackgroundFetchResult result) {
               XCTAssertEqual(result, UIBackgroundFetchResultNewData);
               [handlerExpectation fulfill];
           }];
    [self waitForTestExpectations];

    // Verify everything
    [pushable verify];
    [self.mockedPush verify];
}
@end
