
#import <Foundation/Foundation.h>
#import "UAHTTPConnection.h"
#import "UAInboxMessageList.h"

typedef void (^UAInboxClientSuccessBlock)(void);
typedef void (^UAInboxClientRetrievalSuccessBlock)(NSMutableArray *messages, NSInteger unread);
typedef void (^UAInboxClientFailureBlock)(UAHTTPRequest *request);

/**
* A high level abstraction for performing Rich Push API requests.
*/
@interface UAInboxAPIClient : NSObject

/**
 * Marks a message as read on the server.
 *
 * @param message The message to be marked as read.
 * @param successBlock A block to be executed when the call completes successfully.
 * @param failureBlock A block to be executed if the call fails.
 */
- (void)markMessageRead:(UAInboxMessage *)message
                     onSuccess:(UAInboxClientSuccessBlock)successBlock
                     onFailure:(UAInboxClientFailureBlock)failureBlock;

/**
 * Retrieves the full message list from the server.
 *
 * @param successBlock A block to be executed when the call completes successfully.
 * @param failureBlock A block to be executed if the call fails.
 */
- (void)retrieveMessageListOnSuccess:(UAInboxClientRetrievalSuccessBlock)successBlock
                           onFailure:(UAInboxClientFailureBlock)failureBlock;

/**
 * Performs a batch update request on the server.
 *
 * @param command The batch update command to be executed.
 * @param messages An NSArray of messages to be updated.
 * @param successBlock A block to be executed when the call completes successfully.
 * @param failureBlock A block to be executed if the call fails.
 */

- (void)performBatchUpdateCommand:(UABatchUpdateCommand)command
                      forMessages:(NSArray *)messages
                         onSuccess:(UAInboxClientSuccessBlock)successBlock
                        onFailure:(UAInboxClientFailureBlock)failureBlock;

@end
