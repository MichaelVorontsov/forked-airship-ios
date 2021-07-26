/* Copyright Airship and Contributors */

#import "UAPush.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Protocol to be implemented by internal APNS registration instances. All methods are optional.
 */
@protocol UAAPNSRegistrationProtocol<NSObject>

///---------------------------------------------------------------------------------------
/// @name APNS Registration Protocol Internal Methods
///---------------------------------------------------------------------------------------

@required

/**
 * Get authorized notification settings from iOS.
 *
 * @param completionHandler A completion handler that will be called with the current authorized notification settings, and the authorization
 * status
 */
-(void)getAuthorizedSettingsWithCompletionHandler:(void (^)(UAAuthorizedNotificationSettings, UAAuthorizationStatus))completionHandler;

#if !TARGET_OS_TV
/**
 * Updates APNS registration.
 *
 * @param options The notification options to register.
 * @param categories The categories to register
 * @param completionHandler The completion handler with registration result.
 */
-(void)updateRegistrationWithOptions:(UANotificationOptions)options
                          categories:(NSSet<UNNotificationCategory *> *)categories
                   completionHandler:(nullable void(^)(BOOL success,
                                                       UAAuthorizedNotificationSettings authorizedSettings,
                                                       UAAuthorizationStatus status))completionHandler;
#else
/**
 * Updates APNS registration.
 *
 * @param options The notification options to register.
 * @param completionHandler The completion handler with registration result.
 */
-(void)updateRegistrationWithOptions:(UANotificationOptions)options
                   completionHandler:(nullable void(^)(BOOL success,
                                                       UAAuthorizedNotificationSettings authorizedSettings,
                                                       UAAuthorizationStatus status))completionHandler;
#endif

@end

NS_ASSUME_NONNULL_END
