/* Copyright Airship and Contributors */

#import "UAInAppMessageStyleProtocol.h"
#import "UAInAppMessageTextStyle.h"
#import "UAInAppMessageButtonStyle.h"
#import "UAInAppMessageMediaStyle.h"
#import "UAAirshipAutomationCoreImport.h"


NS_ASSUME_NONNULL_BEGIN

/**
 * The key representing the dismissIconResource in a style plist.
 */
extern NSString *const UAModalDismissIconResourceKey;

/**
 * The key representing the additionalPadding in a style plist.
 */
extern NSString *const UAModalAdditionalPaddingKey;

/**
 * The key representing the top-level text style in a style plist.
 */
extern NSString *const UAModalTextStyleKey;

/**
 * The key representing the header style in a style plist.
 */
extern NSString *const UAModalHeaderStyleKey;

/**
 * The key representing the body style in a style plist.
 */
extern NSString *const UAModalBodyStyleKey;

/**
 * The key representing the button style in a style plist.
 */
extern NSString *const UAModalButtonStyleKey;

/**
 * The key representing the media style in a style plist.
 */
extern NSString *const UAModalMediaStyleKey;

/**
 * The key representing the max width in a style plist.
 */
extern NSString *const UAModalMaxWidthKey;

/**
 * The key representing the max height in a style plist.
 */
extern NSString *const UAModalMaxHeightKey;

/**
 * The key representing the aspect ratio in a style plist.
 */
extern NSString *const UAModalAspectRatioKey;

/**
 * Model object representing a custom style to be applied
 * to modal in-app messages.
 */
NS_SWIFT_NAME(InAppMessageModalStyle)
@interface UAInAppMessageModalStyle : NSObject<UAInAppMessageStyleProtocol>

///---------------------------------------------------------------------------------------
/// @name Modal Style Properties
///---------------------------------------------------------------------------------------

/**
 * The constants added to the default spacing between a view and its parent.
 */
@property(nonatomic, strong) UAPadding *additionalPadding;

/**
 * The dismiss icon image resource name.
 */
@property(nonatomic, strong, nullable) NSString *dismissIconResource;

/**
 * The max width in points.
 */
@property(nonatomic, strong, nullable) NSNumber *maxWidth;

/**
 * The max height in points.
 */
@property(nonatomic, strong, nullable) NSNumber *maxHeight;

/**
 * The aspect ratio.
 */
@property(nonatomic, strong, nullable) NSNumber *aspectRatio;

/**
 * The header text style
 */
@property(nonatomic, strong, nullable) UAInAppMessageTextStyle *headerStyle;

/**
 * The body text style
 */
@property(nonatomic, strong, nullable) UAInAppMessageTextStyle *bodyStyle;

/**
 * The button component style
 */
@property(nonatomic, strong, nullable) UAInAppMessageButtonStyle *buttonStyle;

/**
 * The media component style
 */
@property(nonatomic, strong, nullable) UAInAppMessageMediaStyle *mediaStyle;


/**
 *  Extend full screen on large device.
 */
@property(nonatomic, assign) BOOL extendFullScreenLargeDevice;

@end

NS_ASSUME_NONNULL_END

