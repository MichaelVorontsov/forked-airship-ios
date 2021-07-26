/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UATagGroupsMutation.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Defines changes to perform on tag groups.
 */
@interface UATagGroupsMutation()

///---------------------------------------------------------------------------------------
/// @name Tag Groups Mutation Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Factory method to define a tag mutation with dictionaries of tag group
 * changes to add and remove.
 * @param addTags A dictionary of tag groups to tags to add.
 * @param removeTags A dictionary of tag groups to tags to remove.
 * @return The mutation.
 */
+ (instancetype)mutationWithAddTags:(nullable NSDictionary *)addTags
                         removeTags:(nullable NSDictionary *)removeTags;

/**
 * Compares tag group mutations for equality by payload value.
 *
 * @param mutation The mutation to compare to the receiver.
 */
- (BOOL)isEqualToMutation:(UATagGroupsMutation *)mutation;

@end

NS_ASSUME_NONNULL_END
