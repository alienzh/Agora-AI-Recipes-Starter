//
//  KeyCenter.h
//  VoiceAgent
//
//  Created by qinhui on 2025/11/17.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KeyCenter : NSObject

/**
 Agora Key
 get from Agora Console
 */
+ (NSString *)AG_APP_ID;
+ (NSString *)AG_APP_CERTIFICATE;
+ (NSString *)AG_BASIC_AUTH_KEY;
+ (NSString *)AG_BASIC_AUTH_SECRET;
+ (NSString *)AG_PIPELINE_ID;

@end

NS_ASSUME_NONNULL_END
