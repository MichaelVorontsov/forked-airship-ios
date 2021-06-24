/* Copyright Airship and Contributors */

#import "UAUtils.h"

@class UADispatcher;

NS_ASSUME_NONNULL_BEGIN

/**
 * The UAUtils object provides an interface for utility methods.
 */
@interface UAUtils ()

///---------------------------------------------------------------------------------------
/// @name Device ID
///---------------------------------------------------------------------------------------

/**
 * Gets the device ID from the Keychain.
 *
 * @param completionHandler A completion handler which will be passed the device ID.
 * @param dispatcher The dispatcher to use when invoking the completion handler. If `nil`, a background dispatcher will be used.
 */
+ (void)getDeviceID:(void (^)(NSString *))completionHandler dispatcher:(nullable UADispatcher *)dispatcher;

@end

NS_ASSUME_NONNULL_END
