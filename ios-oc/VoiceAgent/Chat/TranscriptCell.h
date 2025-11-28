//
//  TranscriptCell.h
//  VoiceAgent
//
//  Created by qinhui on 2025/11/17.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class Transcript;

@interface TranscriptCell : UITableViewCell

- (void)configureWithTranscript:(id)transcript;

@end

NS_ASSUME_NONNULL_END

