/* Copyright Airship and Contributors */

#import "UABaseTest.h"

#import "UAInAppMessage+Internal.h"
#import "UAInAppMessageBannerDisplayContent+Internal.h"
#import "UAInAppMessageCustomDisplayContent.h"
#import "UAInAppMessageAirshipLayoutDisplayContent+Internal.h"

@import AirshipCore;

@interface UAInAppMessageTest : UABaseTest
@property(nonatomic, copy) NSDictionary *json;
@property(nonatomic, copy) NSDictionary<NSString*, NSString*> *renderedLocale;
@end

@implementation UAInAppMessageTest

- (void)testJSON {

    self.renderedLocale =  @{@"language" : @"en", @"country" : @"US"};

    // setup
    NSDictionary *originalJSON = @{
                  @"name": @"my name",
                  @"display": @{@"body": @{
                                        @"text":@"the body"
                                        },
                                },
                  @"display_type": UAInAppMessageDisplayTypeBannerValue,
                  @"extra": @{@"foo":@"baz", @"baz":@"foo"},
                  @"actions": @{@"cool":@"story"},
                  @"source": @"remote-data",
                  @"reporting_enabled": @NO,
                  @"display_behavior":@"default",
                  @"rendered_locale" : self.renderedLocale
                  };

    // test
    NSError *error;
    UAInAppMessage *messageFromOriginalJSON = [UAInAppMessage messageWithJSON:originalJSON error:&error];
    XCTAssertNotNil(messageFromOriginalJSON);
    XCTAssertNil(error);

    XCTAssertEqualObjects(@"my name", messageFromOriginalJSON.name);
    XCTAssertEqualObjects(@"the body", ((UAInAppMessageBannerDisplayContent *)(messageFromOriginalJSON.displayContent)).body.text);
    XCTAssertEqual(UAInAppMessageDisplayTypeBanner, messageFromOriginalJSON.displayType);
    XCTAssertEqualObjects(@"baz", messageFromOriginalJSON.extras[@"foo"]);
    XCTAssertEqualObjects(@"foo", messageFromOriginalJSON.extras[@"baz"]);
    XCTAssertEqualObjects(@"story", messageFromOriginalJSON.actions[@"cool"]);
    XCTAssertEqualObjects(UAInAppMessageDisplayBehaviorDefault, messageFromOriginalJSON.displayBehavior);
    XCTAssertEqualObjects(self.renderedLocale, messageFromOriginalJSON.renderedLocale);

    XCTAssertFalse(messageFromOriginalJSON.isReportingEnabled);

    NSDictionary *toJSON = [messageFromOriginalJSON toJSON];
    XCTAssertNotNil(toJSON);
    UAInAppMessage *messageFromToJSON = [UAInAppMessage messageWithJSON:toJSON error:&error];
    XCTAssertNotNil(messageFromToJSON);
    XCTAssertNil(error);

    XCTAssertEqualObjects(messageFromOriginalJSON, messageFromToJSON);
}

- (void)testMinimalJSON {
    // setup
    NSDictionary *originalJSON = @{
                                   @"display": @{@"body": @{
                                                         @"text":@"the body"
                                                         },
                                                 },
                                   @"display_type": UAInAppMessageDisplayTypeBannerValue,
                                   };

    // test
    NSError *error;
    UAInAppMessage *messageFromOriginalJSON = [UAInAppMessage messageWithJSON:originalJSON error:&error];
    XCTAssertNotNil(messageFromOriginalJSON);
    XCTAssertNil(error);

    XCTAssertEqualObjects(nil,messageFromOriginalJSON.name);
    XCTAssertEqualObjects(@"the body",((UAInAppMessageBannerDisplayContent *)(messageFromOriginalJSON.displayContent)).body.text);
    XCTAssertEqual(UAInAppMessageDisplayTypeBanner, messageFromOriginalJSON.displayType);
    XCTAssertEqualObjects(nil,messageFromOriginalJSON.extras[@"foo"]);
    XCTAssertEqualObjects(nil,messageFromOriginalJSON.extras[@"baz"]);
    XCTAssertEqualObjects(nil,messageFromOriginalJSON.actions[@"cool"]);
    XCTAssertEqual(UAInAppMessageSourceAppDefined, messageFromOriginalJSON.source);

    NSDictionary *toJSON = [messageFromOriginalJSON toJSON];
    XCTAssertNotNil(toJSON);
    UAInAppMessage *messageFromToJSON = [UAInAppMessage messageWithJSON:toJSON error:&error];
    XCTAssertNotNil(messageFromToJSON);
    XCTAssertNil(error);

    XCTAssertEqualObjects(messageFromOriginalJSON, messageFromToJSON);
}

- (void)testJSONDefaultSource {
    // setup
    NSDictionary *originalJSON = @{
                                   @"message_id": @"blah",
                                   @"display": @{@"body": @{
                                                         @"text":@"the body"
                                                         },
                                                 },
                                   @"display_type": UAInAppMessageDisplayTypeBannerValue,
                                   };

    NSArray *sources = @[@(UAInAppMessageSourceAppDefined),
                         @(UAInAppMessageSourceRemoteData),
                         @(UAInAppMessageSourceAppDefined)];

    for (NSNumber *source in sources) {
        NSInteger value = [source integerValue];
        NSError *error;
        UAInAppMessage *fromJSON = [UAInAppMessage messageWithJSON:originalJSON
                                                     defaultSource:value
                                                             error:&error];
        XCTAssertNotNil(fromJSON);
        XCTAssertNil(error);

        XCTAssertEqual(value, fromJSON.source);
    }
}

- (void)testJSONWithSource {
    // setup
    NSDictionary *originalJSON = @{
                                   @"message_id": @"blah",
                                   @"display": @{@"body": @{
                                                         @"text":@"the body"
                                                         },
                                                 },
                                   @"source": @"remote-data",
                                   @"display_type": UAInAppMessageDisplayTypeBannerValue,
                                   };


    NSError *error;
    UAInAppMessage *fromJSON = [UAInAppMessage messageWithJSON:originalJSON
                                                 defaultSource:UAInAppMessageSourceLegacyPush
                                                         error:&error];
    XCTAssertNotNil(fromJSON);
    XCTAssertNil(error);

    XCTAssertEqual(UAInAppMessageSourceRemoteData, fromJSON.source);
}

- (void)testBuilder {
    UAInAppMessage *message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder * _Nonnull builder) {
        builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{@"cool": @"story"}];
    }];

    XCTAssertNotNil(message);
}

- (void)testThomasLayout {
    id payload = @{
        @"display_type": UAInAppMessageDisplayTypeAirshipLayoutValue,
        @"display": @{
            @"layout": @{
                @"version": @(1),
                @"view": @{
                    @"type": @"empty_view",
                },
                @"presentation": @{
                    @"type": @"modal",
                    @"default_placement": @{
                        @"size": @{
                            @"width": @"100%",
                            @"height": @"100%",
                        }
                    }
                }
            }
        }
    };
    
    NSError *error;
    UAInAppMessage *message = [UAInAppMessage messageWithJSON:payload error:&error];
    XCTAssertNotNil(message);
    XCTAssertNil(error);
    

    XCTAssertTrue([message.displayContent isKindOfClass:[UAInAppMessageAirshipLayoutDisplayContent class]]);
    XCTAssertEqual(message.displayContent.displayType, UAInAppMessageDisplayTypeAirshipLayout);
    
    UAInAppMessageAirshipLayoutDisplayContent *content = (UAInAppMessageAirshipLayoutDisplayContent *)message.displayContent;
    XCTAssertEqual(payload[@"display"][@"layout"], content.layout);
}

- (void)testInvalidThomasLayout {
    id payload = @{
        @"display_type": UAInAppMessageDisplayTypeAirshipLayoutValue,
        @"display": @{
            @"layout": @{}
        }
    };
    
    NSError *error;
    UAInAppMessage *message = [UAInAppMessage messageWithJSON:payload error:&error];
    XCTAssertNil(message);
    XCTAssertNotNil(error);
}

- (void)testExtend {
    UAInAppMessage *message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder * _Nonnull builder) {
        builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{@"cool": @"story"}];
    }];

    UAInAppMessage *newMessage = [message extend:^(UAInAppMessageBuilder * _Nonnull builder) {
        builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{@"neat": @"rad"}];
    }];

    XCTAssertNotNil(newMessage);
    XCTAssertFalse([newMessage isEqual:message]);
    XCTAssertEqual(newMessage.displayType, message.displayType);
    XCTAssertEqualObjects(newMessage.extras, message.extras);
    XCTAssertEqualObjects(newMessage.actions, message.actions);
    XCTAssertEqual(newMessage.source, message.source);
    XCTAssertEqualObjects(((UAInAppMessageCustomDisplayContent *)newMessage.displayContent).value, @{@"neat" :@"rad"});
}

@end
