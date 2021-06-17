/* Copyright Airship and Contributors */

#import "UAPendingTagGroupStore+Internal.h"
#import "UAPersistentQueue+Internal.h"

#if __has_include("AirshipCore/AirshipCore-Swift.h")
#import <AirshipCore/AirshipCore-Swift.h>
#elif __has_include("Airship/Airship-Swift.h")
#import <Airship/Airship-Swift.h>
#endif

#define kUATagGroupsSentMutationsDefaultMaxAge 60 * 60 * 24 // 1 Day

// Legacy prefix for channel tag group keys
#define kUAPushTagGroupsLegacyKeyPrefix @"UAPush"

// Legacy prefix for named user tag group keys
#define kUANamedUserTagGroupsLegacyKeyPrefix @"UANamedUser"

// Keys for pending mutations and transaction records
#define kUAPendingChannelTagGroupsMutationsKey @"com.urbanairship.tag_groups.pending_channel_tag_groups_mutations"
#define kUAPendingNamedUserTagGroupsMutationsKey @"com.urbanairship.tag_groups.pending_named_user_tag_groups_mutations"

// Max record age
#define kUATagGroupsSentMutationsMaxAgeKey @"com;urbanairship.tag_groups.transaction_records.max_age"

// store keys
NSString * const UATagGroupsChannelStoreKey = @"channel";
NSString * const UATagGroupsNamedUserStoreKey = @"named_user";

@interface UAPendingTagGroupStore ()
@property (nonatomic, copy) NSString *storeKey;
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@property (nonatomic, strong) UAPersistentQueue *pendingTagGroupsMutations;
@end

@implementation UAPendingTagGroupStore

- (instancetype)initWithDataStore:(UAPreferenceDataStore *)dataStore storeKey:(NSString *)storeKey {
    self = [super init];

    if (self) {
        self.dataStore = dataStore;

        self.storeKey = storeKey;

        if ([self.storeKey isEqualToString:UATagGroupsNamedUserStoreKey]) {
            self.pendingTagGroupsMutations = [UAPersistentQueue persistentQueueWithDataStore:dataStore
                                                                                         key:kUAPendingNamedUserTagGroupsMutationsKey];
        } else {
            self.pendingTagGroupsMutations = [UAPersistentQueue persistentQueueWithDataStore:dataStore
                                                                                         key:kUAPendingChannelTagGroupsMutationsKey];
        }

        [self migrateLegacyDataStoreKeys];
    }

    return self;
}

+ (instancetype)channelHistoryWithDataStore:(UAPreferenceDataStore *)dataStore {
    return [[self alloc] initWithDataStore:dataStore storeKey:UATagGroupsChannelStoreKey];
}

+ (instancetype)namedUserHistoryWithDataStore:(UAPreferenceDataStore *)dataStore {
    return [[self alloc] initWithDataStore:dataStore storeKey:UATagGroupsNamedUserStoreKey];
}

- (NSString *)legacyKeyPrefix {
    if ([self.storeKey isEqualToString:UATagGroupsNamedUserStoreKey]) {
        return kUANamedUserTagGroupsLegacyKeyPrefix;
    } else {
        return kUAPushTagGroupsLegacyKeyPrefix;
    }
}

- (NSString *)legacyFormattedKey:(NSString *)actionName {
    return [NSString stringWithFormat:@"%@%@", [self legacyKeyPrefix], actionName];
}

- (NSString *)legacyAddTagsKey {
    return [self legacyFormattedKey:@"AddTagGroups"];
}

- (NSString *)legacyRemoveTagsKey {
    return [self legacyFormattedKey:@"RemoveTagGroups"];
}

- (NSString *)legacyMutationsKey {
    return [self legacyFormattedKey:@"TagGroupsMutations"];
}

- (void)migrateLegacyDataStoreKeys {
    NSString *addTagsKey = [self legacyAddTagsKey];
    NSString *removeTagsKey = [self legacyRemoveTagsKey];
    NSString *mutationsKey = [self legacyMutationsKey];

    NSDictionary *addTags = [self.dataStore objectForKey:addTagsKey];
    NSDictionary *removeTags = [self.dataStore objectForKey:removeTagsKey];

    id encodedMutations = [self.dataStore objectForKey:mutationsKey];
    NSArray *mutations = encodedMutations == nil ? nil : [NSKeyedUnarchiver unarchiveObjectWithData:encodedMutations];

    if (addTags || removeTags) {
        UATagGroupsMutation *mutation = [UATagGroupsMutation mutationWithAddTags:addTags removeTags:removeTags];
        [self addPendingMutation:mutation];
        [self.dataStore removeObjectForKey:addTagsKey];
        [self.dataStore removeObjectForKey:removeTagsKey];
    }

    if (mutations.count) {
        [self.pendingTagGroupsMutations addObjects:mutations];
        [self.dataStore removeObjectForKey:mutationsKey];
    }
}

- (NSTimeInterval)maxSentMutationAge {
    return [self.dataStore doubleForKey:kUATagGroupsSentMutationsMaxAgeKey defaultValue:kUATagGroupsSentMutationsDefaultMaxAge];
}

- (void)setMaxSentMutationAge:(NSTimeInterval)maxAge {
    [self.dataStore setDouble:maxAge forKey:kUATagGroupsSentMutationsMaxAgeKey];
}

- (NSArray<UATagGroupsMutation *> *)pendingMutations {
    return (NSArray<UATagGroupsMutation *>*)[self.pendingTagGroupsMutations objects];
}

- (void)addPendingMutation:(UATagGroupsMutation *)mutation {
    [self.pendingTagGroupsMutations addObject:mutation];
}

- (UATagGroupsMutation *)peekPendingMutation {
    return (UATagGroupsMutation *)[self.pendingTagGroupsMutations peekObject];
}

- (UATagGroupsMutation *)popPendingMutation {
    return (UATagGroupsMutation *)[self.pendingTagGroupsMutations popObject];
}

- (void)collapsePendingMutations {
    [self.pendingTagGroupsMutations collapse:^(NSArray<id<NSSecureCoding>>* objects) {
        return [UATagGroupsMutation collapseMutations:(NSArray<UATagGroupsMutation *>*)objects];
    }];
}

- (void)clearPendingMutations {
    [self.pendingTagGroupsMutations clear];
}

@end
