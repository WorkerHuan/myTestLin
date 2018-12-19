#import <Foundation/Foundation.h>
#import <Cordova/CDV.h>
#import <AudioToolbox/AudioToolbox.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>
#include "linphone/linphonecore.h"

@interface LinphoneView : UIViewController
@property (strong, nonatomic) IBOutlet UIView *lpview;
@property (strong, nonatomic) IBOutlet UIView *lpcview;
@property (strong, nonatomic) IBOutlet UIButton *hangupbtn;
@property (strong, nonatomic) IBOutlet UIButton *micButton;
@property (strong, nonatomic) IBOutlet UIButton *speakerButton;
@property (strong, nonatomic) UILabel *timerLabel;
@property (nonatomic) LinphoneCore *lc;
@property (nonatomic) LinphoneCall *call;
@property (nonatomic) int minutes;
@property (nonatomic) int seconds;
@property (nonatomic, strong) NSTimer* timer;

- (void)startTime;

@end

@interface LinphonePlugin : CDVPlugin{
    LinphoneCore* _lc;
    LinphoneCall* _call;
}

@property (nonatomic) LinphoneCore* _lc;
@property (nonatomic) LinphoneCall* _call;

+ (instancetype)instance;
- (LinphoneCore *)getLc;
- (void)initLinphone:(CDVInvokedUrlCommand*)command;
- (void)accept:(CDVInvokedUrlCommand*)command;
- (void)listenCallState:(CDVInvokedUrlCommand*)command;
- (void)login:(CDVInvokedUrlCommand*)command;
- (void)logout:(CDVInvokedUrlCommand*)command;
- (void)call:(CDVInvokedUrlCommand*)command;
- (void)videocall:(CDVInvokedUrlCommand*)command;
- (void)hangup:(CDVInvokedUrlCommand*)command;
- (void)openVideo:(CDVInvokedUrlCommand*)command;
- (void)toggleSpeaker:(CDVInvokedUrlCommand*)command;
- (void)toggleMicro:(CDVInvokedUrlCommand*)command;
- (void)sendDtmf:(CDVInvokedUrlCommand*)command;

@end
