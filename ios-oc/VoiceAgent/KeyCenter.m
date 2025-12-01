//
//  KeyCenter.m
//  VoiceAgent
//
//  Created by qinhui on 2025/11/17.
//

#import "KeyCenter.h"

static NSString *const AG_APP_ID = @"";
static NSString *const AG_APP_CERTIFICATE = @"";
static NSString *const AG_BASIC_AUTH_KEY = @"";
static NSString *const AG_BASIC_AUTH_SECRET = @"";
static NSString *const AG_PIPELINE_ID = @"";

@implementation KeyCenter

+ (NSString *)AG_APP_ID {
    return AG_APP_ID;
}

+ (NSString *)AG_APP_CERTIFICATE {
    return AG_APP_CERTIFICATE;
}

+ (NSString *)AG_BASIC_AUTH_KEY {
    return AG_BASIC_AUTH_KEY;
}

+ (NSString *)AG_BASIC_AUTH_SECRET {
    return AG_BASIC_AUTH_SECRET;
}

+ (NSString *)AG_PIPELINE_ID {
    return AG_PIPELINE_ID;
}

@end
