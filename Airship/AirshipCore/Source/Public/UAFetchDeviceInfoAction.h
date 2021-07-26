/* Copyright Airship and Contributors */

#import "UAAction.h"

/**
 * Fetches device info.
 *
 * This action is registered under the names fetch_device_info and ^fdi.
 *
 * Expected argument values: none.
 *
 * Valid situations: UASituationLaunchedFromPush,
 * UASituationWebViewInvocation, UASituationManualInvocation,
 * UASituationForegroundInteractiveButton, UASituationBackgroundInteractiveButton,
 * and UASituationAutomation
 *
 * Result value: JSON payload containing the device's channel ID, named user ID, push opt-in status,
 * location enabled status, and tags. An example response as JSON:
 * {
 *     "channel_id": "9c36e8c7-5a73-47c0-9716-99fd3d4197d5",
 *     "push_opt_in": true,
 *     "location_enabled": true,
 *     "named_user": "cool_user",
 *     "tags": ["tag1", "tag2, "tag3"]
 * }
 *
 *
 * Default Registration Predicate: Only accepts UASituationManualInvocation and UASituationWebViewInvocation
 */
@interface UAFetchDeviceInfoAction : NSObject<UAAction>

/**
 * Default registry name for fetch device info action.
 */
extern NSString * const UAFetchDeviceInfoActionDefaultRegistryName;

/**
 * Default registry alias for fetch device info action.
 */
extern NSString * const UAFetchDeviceInfoActionDefaultRegistryAlias;

@end
