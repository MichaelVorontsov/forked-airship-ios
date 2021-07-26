/* Copyright Airship and Contributors */

#import "UAActionRegistryEntry.h"
#import "UAAction.h"
#import "UAActionArguments.h"
#import "UAActionResult.h"

NS_ASSUME_NONNULL_BEGIN

/*
 * Testing extensions and internal properties to Action Registry Entry
 */
@interface UAActionRegistryEntry()

///---------------------------------------------------------------------------------------
/// @name Action Registry Entry Internal Properties
///---------------------------------------------------------------------------------------

/**
 * A mutable internal instance of the Entry's names.
 */
@property (nonatomic, strong) NSMutableArray *mutableNames;

/**
 * The entry's action class.
 */
@property (nonatomic, assign) Class actionClass;

///---------------------------------------------------------------------------------------
/// @name Action Registry Entry Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Add a situation override to the UAActionRegistryEntry.
 * @param situation The situation override to add.
 * @param action The action to be added.
 */
- (void)addSituationOverride:(UASituation)situation withAction:(id<UAAction>)action;

@end

NS_ASSUME_NONNULL_END
