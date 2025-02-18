/* Copyright Airship and Contributors */

#import "UAInAppMessageModalStyle.h"
#import "UAInAppMessageUtils+Internal.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif
NSString *const UAModalDismissIconResourceKey = @"dismissIconResource";
NSString *const UAModalAdditionalPaddingKey = @"additionalPadding";
NSString *const UAModalButtonStyleKey = @"buttonStyle";
NSString *const UAModalTextStyleKey = @"textStyle";
NSString *const UAModalHeaderStyleKey = @"headerStyle";
NSString *const UAModalBodyStyleKey = @"bodyStyle";
NSString *const UAModalMediaStyleKey = @"mediaStyle";
NSString *const UAModalMaxWidthKey = @"maxWidth";
NSString *const UAModalMaxHeightKey = @"maxHeight";
NSString *const UAModalAspectRatioKey = @"aspectRatio";
NSString *const UAModalExtendFullScreenLargeDeviceKey = @"extendFullscreenLargeDevices";


@implementation UAInAppMessageModalStyle

+ (instancetype)style {
    return [[self alloc] init];
}

+ (instancetype)styleWithContentsOfFile:(NSString *)file {
    UAInAppMessageModalStyle *style = [UAInAppMessageModalStyle style];
    if (!file) {
        return style;
    }

    NSString *path = [[NSBundle mainBundle] pathForResource:file ofType:@"plist"];

    if (!path) {
        return style;

    }

    NSDictionary *normalizedModalStyleDict;
    NSDictionary *modalStyleDict = [[NSDictionary alloc] initWithContentsOfFile:path];

    if (modalStyleDict) {
        normalizedModalStyleDict = [UAInAppMessageUtils normalizeStyleDictionary:modalStyleDict];

        id dismissIconResource = normalizedModalStyleDict[UAModalDismissIconResourceKey];
        if (dismissIconResource) {
            if (![dismissIconResource isKindOfClass:[NSString class]]) {
                UA_LWARN(@"Dismiss icon resource name must be a string");
                return nil;
            }
            style.dismissIconResource = dismissIconResource;
        }

        id maxWidthObj = normalizedModalStyleDict[UAModalMaxWidthKey];
        if (maxWidthObj) {
            if ([maxWidthObj isKindOfClass:[NSNumber class]]) {
                maxWidthObj = (NSNumber *)maxWidthObj;
            }
            style.maxWidth = maxWidthObj;
        }

        id maxHeightObj = normalizedModalStyleDict[UAModalMaxHeightKey];
        if (maxHeightObj) {
            if ([maxHeightObj isKindOfClass:[NSNumber class]]) {
                maxHeightObj = (NSNumber *)maxHeightObj;
            }
            style.maxHeight = maxHeightObj;
        }
        
        id aspectRatioObj = normalizedModalStyleDict[UAModalAspectRatioKey];
        if (aspectRatioObj) {
            if ([aspectRatioObj isKindOfClass:[NSNumber class]]) {
                aspectRatioObj = (NSNumber *)aspectRatioObj;
            }
            style.aspectRatio = aspectRatioObj;
        }

        style.additionalPadding = [UAPadding paddingWithDictionary:normalizedModalStyleDict[UAModalAdditionalPaddingKey]];
        style.headerStyle = [UAInAppMessageTextStyle styleWithDictionary:normalizedModalStyleDict[UAModalHeaderStyleKey]];
        style.bodyStyle = [UAInAppMessageTextStyle styleWithDictionary:normalizedModalStyleDict[UAModalBodyStyleKey]];
        style.buttonStyle = [UAInAppMessageButtonStyle styleWithDictionary:normalizedModalStyleDict[UAModalButtonStyleKey]];
        style.mediaStyle = [UAInAppMessageMediaStyle styleWithDictionary:normalizedModalStyleDict[UAModalMediaStyleKey]];

        id extendFullScreenLargeDeviceObj = normalizedModalStyleDict[UAModalExtendFullScreenLargeDeviceKey];
        if (extendFullScreenLargeDeviceObj) {
            if ([extendFullScreenLargeDeviceObj isKindOfClass:[NSNumber class]]) {
                style.extendFullScreenLargeDevice = [extendFullScreenLargeDeviceObj boolValue];
            }
        }
        
        UA_LTRACE(@"In-app modal style options: %@", [normalizedModalStyleDict description]);
    }

    return style;
}

#pragma mark -
#pragma KVC Overrides
- (void)setValue:(id)value forUndefinedKey:(NSString *)key {
    // Be leniant and no-op for other undefined keys
    // The `super` implementation throws an exception. We'll just log.
    UA_LDEBUG(@"Ignoring invalid style key: %@", key);
}

@end

