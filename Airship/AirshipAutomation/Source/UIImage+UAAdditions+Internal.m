/* Copyright Airship and Contributors */

#import "UIImage+UAAdditions+Internal.h"
#import <ImageIO/ImageIO.h>

@implementation UIImage (UAAdditions)

+ (NSTimeInterval)durationFromProperties:(CFDictionaryRef)properties {
    NSTimeInterval duration = 0;

    if (properties) {
        NSDictionary *frameProperties = (__bridge NSDictionary *)properties;
        NSDictionary *gifProperties = frameProperties[(NSString *)kCGImagePropertyGIFDictionary];

        duration = [gifProperties[(NSString *)kCGImagePropertyGIFUnclampedDelayTime] doubleValue];
        if (!duration) {
            duration = [gifProperties[(NSString*)kCGImagePropertyGIFDelayTime] doubleValue];
        }
    }

    return duration;
}

+ (UIImage *)animatedImageWithImageSource:(CGImageSourceRef)source {
    NSMutableArray *images = [NSMutableArray array];
    NSTimeInterval fullDuration = 0;

    for (int i = 0; i < CGImageSourceGetCount(source); i++) {
        CGImageRef imageRef = CGImageSourceCreateImageAtIndex(source, i, NULL);
        if (!imageRef) {
            continue;
        }

        CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(source, i, NULL);
        NSTimeInterval duration = [self durationFromProperties:properties];
        if (properties) {
            CFRelease(properties);
        }

        UIImage *image = [UIImage imageWithCGImage:imageRef];
        CGImageRelease(imageRef);

        if (image && duration) {
            fullDuration += duration;

            // Fill in frames for every centisecond
            int centiseconds = (int)(duration * 100);
            for (int i = 0; i < centiseconds; i++) {
                [images addObject:image];
            }
        }
    }

    return [self animatedImageWithImages:images duration:fullDuration];
}

+ (UIImage *)fancyImageWithData:(NSData *)data {
    CGImageSourceRef source = CGImageSourceCreateWithData((CFDataRef) data, NULL);

    UIImage *image;
    
    if (source && CGImageSourceGetCount(source) > 1) {
        image = [self animatedImageWithImageSource:source];
    } else {
        image = [self imageWithData:data];
    }

    if (source) {
        CFRelease(source);
    }

    return image;
}

@end
