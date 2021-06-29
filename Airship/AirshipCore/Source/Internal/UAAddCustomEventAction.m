/* Copyright Airship and Contributors */

#import "UAAddCustomEventAction.h"
#import "UAirship.h"
#import "UAAnalytics.h"
#import "UAAnalytics+Internal.h"

#if __has_include("AirshipCore/AirshipCore-Swift.h")
#import <AirshipCore/AirshipCore-Swift.h>
#elif __has_include("Airship/Airship-Swift.h")
#import <Airship/Airship-Swift.h>
#endif

NSString * const UAAddCustomEventActionErrorDomain = @"UAAddCustomEventActionError";
NSString * const UAAddCustomEventActionDefaultRegistryName = @"add_custom_event_action";

@implementation UAAddCustomEventAction

- (BOOL)acceptsArguments:(UAActionArguments *)arguments {
    if ([arguments.value isKindOfClass:[NSDictionary class]]) {
        NSString *eventName = [arguments.value valueForKey:UACustomEvent.eventNameKey];
        if (eventName) {
            return YES;
        } else {
            UA_LERR(@"UAAddCustomEventAction requires an event name in the event data.");
            return NO;
        }
    } else {
        UA_LERR(@"UAAddCustomEventAction requires a dictionary of event data.");
        return NO;
    }
}

- (void)performWithArguments:(UAActionArguments *)arguments
           completionHandler:(UAActionCompletionHandler)completionHandler {

    NSDictionary *dict = [NSDictionary dictionaryWithDictionary:arguments.value];

    NSString *eventName = [self parseStringFromDictionary:dict key:UACustomEvent.eventNameKey];
    NSString *eventValue = [self parseStringFromDictionary:dict key:UACustomEvent.eventValueKey];
    NSString *interactionID = [self parseStringFromDictionary:dict key:UACustomEvent.eventInteractionIDKey];
    NSString *interactionType = [self parseStringFromDictionary:dict key:UACustomEvent.eventInteractionTypeKey];
    NSString *transactionID = [self parseStringFromDictionary:dict key:UACustomEvent.eventTransactionIDKey];
    id properties = dict[UACustomEvent.eventPropertiesKey];

    UACustomEvent *event = [UACustomEvent eventWithName:eventName valueFromString:eventValue];
    event.transactionID = transactionID;

    if (interactionID || interactionType) {
        event.interactionType = interactionType;
        event.interactionID = interactionID;
    } else {
        id messageID = [arguments.metadata objectForKey:UAActionMetadataInboxMessageIDKey];
        if (messageID) {
            [event setInteractionFromMessageCenterMessage:messageID];
        }
    }

    // Set the conversion send ID if the action was triggered from a push
    event.conversionSendID = arguments.metadata[UAActionMetadataPushPayloadKey][@"_"];

    // Set the conversion send Metadata if the action was triggered from a push
    event.conversionPushMetadata = arguments.metadata[UAActionMetadataPushPayloadKey][kUAPushMetadata];

    NSMutableDictionary *propertyDictionary = [NSMutableDictionary dictionary];
    
    if (properties && [properties isKindOfClass:[NSDictionary class]]) {
        for (id key in properties) {

            if (![key isKindOfClass:[NSString class]]) {
                UA_LWARN(@"Only String keys are allowed for custom event properties.");
                continue;
            }

            id value = properties[key];
            [propertyDictionary setValue:value forKey:key];
        }
    }

    event.properties = propertyDictionary;
    
    if ([event isValid]) {
        [event track];
        completionHandler([UAActionResult emptyResult]);
    } else {
        NSError *error = [NSError errorWithDomain:UAAddCustomEventActionErrorDomain
                                             code:UAAddCustomEventActionErrorCodeInvalidEventName
                                         userInfo:@{NSLocalizedDescriptionKey:@"Invalid custom event. Verify the event name is specified, event value must be a number."}];

        completionHandler([UAActionResult resultWithError:error]);
    }
}

/**
 * Helper method to parse a string from a dictionary's value.
 * @param dict The dictionary to be parsed.
 * @param key The specified key.
 * @return The string parsed from the dicitionary.
 */
- (NSString *)parseStringFromDictionary:(NSDictionary *)dict key:(NSString *)key {
    id value = [dict objectForKey:key];
    if (!value) {
        return nil;
    } else if ([value isKindOfClass:[NSString class]]) {
        return value;
    } else if ([value isKindOfClass:[NSNumber class]]) {
        return [value stringValue];
    } else {
        return [value description];
    }
}

@end
