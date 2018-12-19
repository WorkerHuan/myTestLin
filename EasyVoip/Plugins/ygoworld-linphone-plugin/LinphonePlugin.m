#import "LinphonePlugin.h"
#import <Cordova/CDV.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import "LinphoneManager.h"

extern void libmsamr_init(MSFactory *factory);
extern void libmsx264_init(MSFactory *factory);
extern void libmsopenh264_init(MSFactory *factory);
extern void libmssilk_init(MSFactory *factory);
extern void libmswebrtc_init(MSFactory *factory);

@implementation LinphonePlugin

@synthesize  _lc;
@synthesize  _call;

static LinphonePlugin *himself;
NSString *_callbackId;
NSString *_loginCallbackId;
bool *_isMute = FALSE;
bool *_isSpeaker = FALSE;
static const char *_calleeAccount = NULL;
static int total=0;
static const LinphoneView *_lview;

+ (instancetype)instance {
    return himself;
}

- (LinphoneCore *)getLc {
    return _lc;
}

- (void)pluginInitialize {
    NSLog(@"------------------- Ygoworld Linphone Plugin Initialize Finish --------------------");
}

- (void)initLinphone:(CDVInvokedUrlCommand*)command {
    [self startLinphoneCore];
}

- (void)startLinphoneCore {
    //    ms_factory_new_with_voip_and_directories("liblinphone-sdk/apple-darwin/lib/mediastreamer/plugins", NULL);
    
    himself = self;
    
    // 打印debug信息
    linphone_core_set_log_level(ORTP_DEBUG);
    
    // 单例工厂
    LinphoneFactory *factory = linphone_factory_get();
    //
    //    // 回调对象
    LinphoneCoreCbs *cbs = linphone_factory_create_core_cbs(factory);
    //
    //    // 核心
    NSString *config_path = [[NSBundle mainBundle] pathForResource:@"linphonerc" ofType: nil];
    NSString *factory_config_path = [[NSBundle mainBundle] pathForResource:@"linphonerc-factory" ofType: nil];
    _lc = linphone_factory_create_core(factory, cbs, [config_path cStringUsingEncoding: NSUTF8StringEncoding], [factory_config_path cStringUsingEncoding: NSUTF8StringEncoding]);
    
    // Load plugins if available in the linphone SDK - otherwise these calls will do nothing
    MSFactory *f = linphone_core_get_ms_factory(_lc);
    libmssilk_init(f);
    libmsamr_init(f);
    libmsx264_init(f);
    libmsopenh264_init(f);
    libmswebrtc_init(f);
    linphone_core_reload_ms_plugins(_lc, NULL);
    
    // 设置铃声
    NSString *ringPath = [[NSBundle mainBundle] pathForResource: @"shortring.caf" ofType: nil];
    linphone_core_set_ring(_lc, [ringPath cStringUsingEncoding: NSUTF8StringEncoding]);
    
    NSString *ringbackPath = [[NSBundle mainBundle] pathForResource: @"ringback.wav" ofType: nil];
    linphone_core_set_ringback(_lc, [ringbackPath cStringUsingEncoding: NSUTF8StringEncoding]);
    
    // 监听各种状态
    //注册状态
    linphone_core_cbs_set_registration_state_changed(cbs, registrationStateChangedCb);
    //呼叫状态
    linphone_core_cbs_set_call_state_changed(cbs, (LinphoneCoreCallStateChangedCb)callStateChangedCb);
    
    //音频编码
    [self configureCodec];
    
    //视频参数
    linphone_core_enable_video_capture(_lc, true);
    linphone_core_enable_video_display(_lc, true);
    linphone_core_enable_video_preview(_lc, true);
    linphone_core_use_preview_window(_lc, true);
    linphone_core_self_view_enabled(_lc);
    
    //摄像头 默认前置
    linphone_core_set_video_device(_lc, 0);
    
    [[NSRunLoop currentRunLoop] addTimer: [NSTimer timerWithTimeInterval:0.02 target:self selector:@selector(interate) userInfo:nil repeats:YES] forMode: NSRunLoopCommonModes];
}

- (void)interate{
    if (_lc) {
        linphone_core_iterate(_lc);
    }
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    //First refresh registration
    linphone_core_refresh_registers(_lc);
    // Get the default proxyCfg in Linphone
    NSLog(@"run in background mode");
    LinphoneProxyConfig* proxyCfg = NULL;
    proxyCfg = linphone_core_get_default_proxy_config(_lc);
    //wait for registration answer
    int i=0;
    while (!linphone_proxy_config_is_registered(proxyCfg) && i++<40 ) {
        linphone_core_iterate(_lc);
        usleep(100000);
    }
    //register keepalive handler
    [[UIApplication sharedApplication] setKeepAliveTimeout:600/*minimal interval is 600 s*/
                                                   handler:^{
                                                       //refresh sip registration
                                                       linphone_core_refresh_registers(_lc);
                                                       //make sure sip REGISTER is sent
                                                       linphone_core_iterate(_lc);
                                                   }];
}

- (void)configureCodec{
    PayloadType *pt;
    const MSList *audio_codecs = linphone_core_get_audio_codecs(_lc);
    const MSList *codec = audio_codecs;
    PayloadType *g729 = linphone_core_find_payload_type(_lc, "G729", 8000, -1);
    while (codec) {
        pt = codec->data;
        if (g729 && pt == g729) {
            linphone_core_enable_payload_type(_lc, g729, TRUE);
        } else {
            linphone_core_enable_payload_type(_lc, pt, FALSE);
        }
        codec = codec->next;
    }
    
}

// MARK: linphone 注册状态
static void registrationStateChangedCb(LinphoneCore *lc, LinphoneProxyConfig *cfg, LinphoneRegistrationState cstate, const char *message) {
    NSLog(@"%d", cstate);
    // 发送通知
    [[NSNotificationCenter defaultCenter] postNotificationName:@"LinphoneRegisterationStateChangeCbNOotification" object: @(cstate)];
    
    NSString *status = @"";
    
    switch (cstate) {
        case LinphoneRegistrationNone:
            NSLog(@"还没有注册");
            status=@"RegistrationNone";
            break;
        case LinphoneRegistrationProgress:
            NSLog(@"正在注册");
            status=@"RegistrationProgress";
            break;
            
        case LinphoneRegistrationOk:
            NSLog(@"注册完成");
            status=@"RegistrationOk";
            break;
            
        case LinphoneRegistrationCleared:
            NSLog(@"注册被取消");
            status=@"RegistrationCleared";
            break;
            
        case LinphoneRegistrationFailed:
            NSLog(@"注册失败");
            status=@"RegistrationFailed";
            break;
        default:
            break;
    }
    
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:status];
    [pluginResult setKeepCallbackAsBool:YES];
    [himself.commandDelegate sendPluginResult:pluginResult callbackId:_loginCallbackId];
    
}

// MARK: 监听电话的状态
static void callStateChangedCb(LinphoneCore *lc, LinphoneCall *call, LinphoneCallState cstate, const char *message) {
    
    NSLog(@"=======");
    
    const char *remoteContact = linphone_call_get_remote_contact(call);
    NSLog(@"remoteContact: %s", remoteContact);
    
    NSLog(@"cstate: %d", cstate);
    logCallState(cstate);
    NSLog(@"message: %s", message);
    NSLog(@"=======");
    NSString *status = @"";
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"LinphoneCallStateChangeCbNotification" object: @(cstate)];
    NSMutableDictionary *resultDic = [[NSMutableDictionary alloc]init];
    
    switch(cstate) {
        case LinphoneCallIncomingReceived:
        {
            NSLog(@"收到来电");
            const LinphoneCallParams *callParams = linphone_call_get_remote_params(call);
            const char *addr = linphone_call_get_remote_address_as_string(call);
            NSString *callerNum=[NSString stringWithUTF8String:addr];
            
//            bool *isVideo = linphone_call_params_video_enabled(callParams);
            
            
            if (linphone_call_params_video_enabled(callParams)){
                status=@"VideoIncomingCall";
            } else {
                status=@"AudioIncomingCall";
            }
//            [resultDic setValue:status forKey:@"eventName"];
            [resultDic setValue:callerNum forKey:@"addrStr"];

            break;
        }
        case LinphoneCallReleased:
            status=@"CallReleased";
            if (_lview) {
               [_lview dismissViewControllerAnimated:YES completion:nil];
                _lview = NULL;
            }
            if (himself._call) {
                himself._call = NULL;
            }
            if (_calleeAccount) {
                _calleeAccount = NULL;
            }
            [resultDic setValue:[NSNumber numberWithInt:total] forKey:@"total"];
            break;
        case LinphoneCallError:
            status=@"Error";
            break;
        case LinphoneCallEnd:
            status=@"CallEnd";
            if (_lview) {
                [_lview dismissViewControllerAnimated:YES completion:nil];
                _lview = NULL;
            }
            if (himself._call) {
                himself._call = NULL;
            }
            if (_calleeAccount) {
                _calleeAccount = NULL;
            }
            [resultDic setValue:[NSNumber numberWithInt:total] forKey:@"total"];
            break;
        case LinphoneCallConnected:
            status=@"CallConnected";
            break;
        case LinphoneCallIdle:
            status=@"Idle";
            break;
        case LinphoneCallOutgoingInit:
            status=@"OutgoingInit";
            break;
        case LinphoneCallEarlyUpdating:
            status=@"CallEarlyUpdating";
            break;
        case LinphoneCallStreamsRunning:
            status=@"StreamsRunning";
            if (_lview){
                [_lview startTime];//开始计时
            }
            break;
        case LinphoneCallOutgoingRinging:
            status=@"OutgoingRinging";
            break;
        case LinphoneCallOutgoingProgress:
            status=@"OutgoingProgress";
            break;
        case LinphoneCallIncomingEarlyMedia:
            status=@"CallIncomingEarlyMedia";
            break;
        case LinphoneCallOutgoingEarlyMedia:
            status=@"OutgoingEarlyMedia";
            break;
        case LinphoneCallEarlyUpdatedByRemote:
            status=@"CallEarlyUpdatedByRemote";
            break;
        case LinphoneCallUpdatedByRemote:
            status=@"CallUpdatedByRemote";
            break;
        case LinphoneCallPaused:
            status=@"Paused";
            break;
        case LinphoneCallPausing:
            status=@"Pausing";
            break;
        case LinphoneCallRefered:
            status=@"Refered";
            break;
        case LinphoneCallResuming:
            status=@"Resuming";
            break;
        case LinphoneCallUpdating:
            status=@"CallUpdating";
            break;
        case LinphoneCallPausedByRemote:
            status=@"PausedByRemote";
            break;
        default:
            status=@"Error";
            break;
            
    }
    [resultDic setValue:status forKey:@"eventName"];
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:resultDic];
    [pluginResult setKeepCallbackAsBool:YES];
    [himself.commandDelegate sendPluginResult:pluginResult callbackId:_callbackId];
}

void logCallState(LinphoneCallState cstate) {
    switch (cstate) {
        case LinphoneCallIdle:
            NSLog(@"初始化电话状态");
            break;
        case LinphoneCallIncomingReceived:
            NSLog(@"收到来电");
            break;
        case LinphoneCallOutgoingInit:
            NSLog(@"初始化拨出电话");
            break;
        case LinphoneCallOutgoingProgress:
            NSLog(@"拨出电话进行中......");
            break;
        case LinphoneCallOutgoingEarlyMedia:
            NSLog(@"LinphoneCallOutgoingEarlyMedia");
            break;
        case LinphoneCallConnected:
            NSLog(@"电话接通");
            break;
        case LinphoneCallStreamsRunning:
            NSLog(@"电话流 稳定运行中.....");
            break;
        case LinphoneCallPausing:
            NSLog(@"电话暂停");
            break;
        case LinphoneCallResuming:
            NSLog(@"电话恢复");
            break;
        case LinphoneCallRefered:
            NSLog(@"LinphoneCallRefered");
            break;
        case LinphoneCallError:
            NSLog(@"电话错误");
            break;
        case LinphoneCallEnd:
            NSLog(@"电话结束");
            break;
        case LinphoneCallPausedByRemote:
            NSLog(@"电话被远程暂停");
            break;
        case LinphoneCallUpdatedByRemote:
            NSLog(@"LinphoneCallUpdatedByRemote used for example when video is added by remote");
            break;
        case LinphoneCallIncomingEarlyMedia:
            NSLog(@"LinphoneCallIncomingEarlyMedia");
            break;
        case LinphoneCallUpdating:
            NSLog(@"LinphoneCallUpdating");
            break;
        case LinphoneCallReleased:
            NSLog(@"LinphoneCallReleased");
            break;
        case LinphoneCallEarlyUpdatedByRemote:
            NSLog(@"LinphoneCallEarlyUpdatedByRemote");
            break;
        case LinphoneCallEarlyUpdating:
            NSLog(@"LinphoneCallEarlyUpdating");
            break;
        default:
            break;
    }
}

- (void)login:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"OK"];
    NSString* userName = [command.arguments objectAtIndex:0];
    NSString* password = [command.arguments objectAtIndex:1];
    NSString* domain = [command.arguments objectAtIndex:2];
    NSString* transport = [command.arguments objectAtIndex:3];
    NSString* proxyServer = [command.arguments objectAtIndex:4];

    _loginCallbackId = command.callbackId;
    
    bctbx_list_t *payloadType = linphone_core_get_audio_payload_types(_lc);
    

    [self registeByUserName:userName pwd:password domain:domain transport:transport proxyServer:proxyServer];

    [pluginResult setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:_loginCallbackId];
    [[LinphoneManager instance] resetLinphoneCore];
}

- (void)accept:(CDVInvokedUrlCommand*)command {
    bool isAccept = [command.arguments objectAtIndex:0];
    LinphoneCall *call = linphone_core_get_current_call(_lc);
    _call = call;
    if (!call) {
        return ;
    }
    if ( isAccept == TRUE) {
        if (linphone_call_params_video_enabled(linphone_call_get_remote_params(call))) {
//            LinphoneCallParams *cparams = linphone_core_create_call_params(_lc, _call);
//            linphone_call_params_enable_video(cparams, true);
//            linphone_call_params_enable_audio(cparams, true);
        
//            linphone_call_accept_with_params(_call, cparams);
            _lview = [[LinphoneView alloc]init];
            UIViewController *rootViewController = [[[UIApplication sharedApplication] keyWindow] rootViewController];
            _lview.lc = _lc;
            _lview.call = call;
            [rootViewController presentViewController:_lview animated:NO completion:nil];
        } else {
            linphone_call_accept(call);
        }
    } else {
        linphone_call_decline(call, LinphoneReasonDeclined);
    }
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"OK"];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    
}

- (void)hangup:(CDVInvokedUrlCommand*)command {
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"OK"];
    
    LinphoneCall *call = linphone_core_get_current_call(_lc);
    if(call && linphone_call_get_state(call) != LinphoneCallEnd){
        linphone_call_terminate(call);
        linphone_call_unref(call);
    }
    call = NULL;
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)openVideo:(CDVInvokedUrlCommand*)command {
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"OK"];
    
//    [[LinphoneUtils instance] openVideo];
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)listenCallState:(CDVInvokedUrlCommand*)command
{
    _callbackId = command.callbackId;
}

- (void)logout:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"OK"];
    
    // Get the default proxyCfg in Linphone
    LinphoneProxyConfig* proxyCfg = NULL;
    proxyCfg = linphone_core_get_default_proxy_config(_lc);
    
    // To unregister from SIP
    linphone_proxy_config_edit(proxyCfg);
    linphone_proxy_config_enable_register(proxyCfg, false);
    linphone_proxy_config_done(proxyCfg);
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)call:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"OK"];
    NSString* userName = [command.arguments objectAtIndex:0];
    NSString* displayName = [command.arguments objectAtIndex:1];
    bool isVideo = [command.arguments objectAtIndex:2];
    NSString *video = [command.arguments objectAtIndex:2];
    int intString = [video intValue];
    if (intString == 1) {
        isVideo = TRUE;
    } else {
        isVideo = FALSE;
    }
    
    NSString *num = [NSString stringWithFormat:@"%@@%@",userName, @"ims.huawei.com"];
    
    const char *calleeAccount = [num cStringUsingEncoding: NSUTF8StringEncoding];
    
    if (isVideo) {
        _calleeAccount = calleeAccount;
//        if (_calleeAccount != NULL) {//主叫切换视频界面
            _lview = [[LinphoneView alloc]init];
            UIViewController *rootViewController = [[[UIApplication sharedApplication] keyWindow] rootViewController];
            _lview.lc = _lc;
//            _lview.call = _call;
            [rootViewController presentViewController:_lview animated:NO completion:nil];
//        }
    } else {
        _call = linphone_core_invite(_lc, calleeAccount);
    }
    
    if (_call) {
        linphone_call_ref(_call);
    }
    
    [pluginResult setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)videocall:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"OK"];
    NSString* address = [command.arguments objectAtIndex:0];
    NSString* displayName = [command.arguments objectAtIndex:1];
    
    LinphoneCallParams *cparams = linphone_core_create_call_params(_lc, _call);
    linphone_call_enable_camera(_lc, true);
    linphone_call_params_enable_video(cparams, true);
    linphone_call_params_enable_audio(cparams, true);
//    linphone_core_accept_call_with_params(_lc, _call, cparams);
    
    _call = linphone_core_invite_with_params(_lc, (char *)[address UTF8String], cparams);
    linphone_call_ref(_call);
}

- (void)toggleVideo:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"OK"];
    bool isenabled = FALSE;
    
    if (_call != NULL && linphone_call_params_get_used_video_payload_type(linphone_call_get_current_params(_call))) {
//        [self.viewController presentViewController:[[VideoViewController alloc] init] animated: YES completion:nil];
    }
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)toggleSpeaker:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"OK"];
    NSString *speaker = [command.arguments objectAtIndex:0];
    int intString = [speaker intValue];
    bool isSpeaker = FALSE;
    if (intString == 1) {
        isSpeaker = TRUE;
    }
    if (_call != NULL && linphone_call_get_state(_call) != LinphoneCallEnd){
        if (isSpeaker) {
            UInt32 audioRouteOverride = kAudioSessionOverrideAudioRoute_Speaker;
            AudioSessionSetProperty(kAudioSessionProperty_OverrideAudioRoute, sizeof(audioRouteOverride),
                                    &audioRouteOverride);
        } else {
            UInt32 audioRouteOverride = kAudioSessionOverrideAudioRoute_None;
            AudioSessionSetProperty(kAudioSessionProperty_OverrideAudioRoute, sizeof(audioRouteOverride),
                                    &audioRouteOverride);
        }
    }
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)toggleMicro:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"OK"];
    bool isenabled = FALSE;
    
    if(_call && linphone_call_get_state(_call) != LinphoneCallEnd){
        linphone_core_enable_mic(_lc, isenabled);
    }
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)sendDtmf:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"OK"];
    NSString* dtmf = [command.arguments objectAtIndex:0];
    
    if(_call && linphone_call_get_state(_call) != LinphoneCallEnd){
        linphone_call_send_dtmf(_call, [dtmf characterAtIndex:0]);
    }
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)registeByUserName:(NSString *)userName pwd:(NSString *)pwd domain:(NSString *)domain transport:(NSString *)transport proxyServer:(NSString *)proxyServer{
    
    //设置超时，默认30s
    // linphone_core_set_inc_timeout(LC, 60);
    
    //创建proxy配置表
    LinphoneProxyConfig *proxyCfg = linphone_core_create_proxy_config(_lc);
    
    char *normalize_phone_number = linphone_proxy_config_normalize_phone_number(proxyCfg, [userName cStringUsingEncoding: NSUTF8StringEncoding]);
    
    //初始化电话号码
    linphone_proxy_config_normalize_phone_number(proxyCfg,userName.UTF8String);
    
    //创建地址
    NSString *address = [NSString stringWithFormat:@"sip:%@@%@", userName,domain];//如:sip:123456@sip.com
    LinphoneAddress *identify = linphone_address_new(address.UTF8String);
    linphone_address_set_username(identify, normalize_phone_number);
    
    linphone_proxy_config_set_identity_address(proxyCfg, identify);
    
    //NAT策略
//    LinphoneNatPolicy *natPolicy = linphone_core_create_nat_policy(_lc);
//    linphone_nat_policy_enable_stun(natPolicy, true);
//    linphone_nat_policy_enable_ice(natPolicy, true);
//    linphone_nat_policy_enable_turn(natPolicy, TRUE);
//    linphone_nat_policy_set_stun_server_username(natPolicy, [@"leeson" cStringUsingEncoding:NSUTF8StringEncoding]);
//    linphone_nat_policy_set_stun_server(natPolicy, [@"tt.ygoworld.com" cStringUsingEncoding:NSUTF8StringEncoding]);
//    linphone_proxy_config_set_nat_policy(proxyCfg, natPolicy);
//    LinphoneAuthInfo *natAuth = linphone_auth_info_new([@"leeson" cStringUsingEncoding:NSUTF8StringEncoding], [@"leeson" cStringUsingEncoding:NSUTF8StringEncoding], [@"@Ygoworld" cStringUsingEncoding:NSUTF8StringEncoding], nil, nil, [@"tt.ygoworld.com" cStringUsingEncoding:NSUTF8StringEncoding]);
//    linphone_core_add_auth_info(_lc, natAuth);
    
    //userId
    NSString *userId = [NSString stringWithFormat:@"%@@%@",userName, domain];
    
    //创建鉴权
    LinphoneAuthInfo *info;
    if ([domain isEqualToString:@"ims.huawei.com"]||[domain isEqualToString:@"ims.rtarf.mi.th"]) {
        info = linphone_auth_info_new(normalize_phone_number, userId.UTF8String, pwd.UTF8String, nil, linphone_address_get_domain(identify), linphone_address_get_domain(identify));
    } else {
     info = linphone_auth_info_new(userName.UTF8String, userName.UTF8String, pwd.UTF8String, nil, nil, linphone_address_get_domain(identify));
    }
    
    // 服务器地址(proxy)
//    NSString *serverAddr = [NSString stringWithFormat:@"sip:%@", proxyServer];
    
        NSString *serverAddr = [NSString stringWithFormat:@"sip:%@;transport=%@", proxyServer, @"udp"];
    linphone_proxy_config_set_server_addr(proxyCfg, [serverAddr cStringUsingEncoding:NSUTF8StringEncoding]);
    
    //设置route
    linphone_proxy_config_set_route(proxyCfg, [serverAddr cStringUsingEncoding: NSUTF8StringEncoding]);
    
    linphone_proxy_config_enable_register(proxyCfg, TRUE);

    //添加证书
    linphone_core_add_auth_info(_lc, info);
    
    //使用随机端口
    LinphoneSipTransports transportValue = {-1, -1, -1, -1};
    linphone_core_set_sip_transports(_lc, &transportValue);
    
    
    //注册
    linphone_proxy_config_enable_register(proxyCfg, TRUE);
    
    //添加到配置表,添加到linphone_core
    linphone_core_add_proxy_config(_lc, proxyCfg);
    
    //设置成默认配置表
    linphone_core_set_default_proxy_config(_lc, proxyCfg);
    
    //销毁地址
    linphone_address_unref(identify);
}

@end


@implementation LinphoneView

- (id)initWithNibName:(NSString*)nibNameOrNil bundle:(NSBundle*)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    return self;
}

- (id)init
{
    self = [super init];
    return self;
}

- (void)viewWillAppear:(BOOL)animated
{
    UITapGestureRecognizer* tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapContainer:)];
    UITapGestureRecognizer* tapPreview = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapPreview:)];
    
    _hangupbtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _micButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _speakerButton = [UIButton buttonWithType:UIButtonTypeCustom];
    
    _timerLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, [UIScreen mainScreen].bounds.size.height/2 + 30, [UIScreen mainScreen].bounds.size.width, 30)];
    _timerLabel.textAlignment = NSTextAlignmentCenter;
    _timerLabel.font = [UIFont systemFontOfSize:15];
    _timerLabel.textColor = [UIColor whiteColor];
    
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(startTimer) userInfo:nil repeats:YES];
    
    int margin =([UIScreen mainScreen].bounds.size.width/3 - 63)/2;
    
    [_hangupbtn setFrame:CGRectMake([UIScreen mainScreen].bounds.size.width/3 + margin, [UIScreen mainScreen].bounds.size.height/2 + 150, 63, 63)];
    [_micButton setFrame:CGRectMake(margin, [UIScreen mainScreen].bounds.size.height/2 + 150, 63, 63)];
    [_speakerButton setFrame:CGRectMake(([UIScreen mainScreen].bounds.size.width/3)*2 + margin, [UIScreen mainScreen].bounds.size.height/2 + 150, 63, 63)];

    [_hangupbtn setImage:[UIImage imageNamed:@"ring_off"] forState:UIControlStateNormal];
    [_micButton setImage:[UIImage imageNamed:@"muteclose"] forState:UIControlStateNormal];
    [_speakerButton setImage:[UIImage imageNamed:@"speakerclose"] forState:UIControlStateNormal];
    
    [_hangupbtn addTarget:self action:@selector(hangupEvt:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_hangupbtn];
    [_micButton addTarget:self action:@selector(micEvt:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_micButton];
    [_speakerButton addTarget:self action:@selector(speakerEvt:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_speakerButton];
    
    
    _lpview = [[UIView alloc] initWithFrame:CGRectMake([UIScreen mainScreen].bounds.size.width - 120, 3, 120, 160)];
    _lpview.backgroundColor = [UIColor blackColor];
    [_lpview addGestureRecognizer:tapPreview];
    
    _lpcview = [[UIView alloc] initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height)];
    _lpcview.backgroundColor = [UIColor blackColor];
    
    [_lpcview addGestureRecognizer:tap];
    
    [self.view addSubview:_lpcview];
    [self.view addSubview:_lpview];
    [self.view addSubview:_hangupbtn];
    [self.view addSubview:_micButton];
    [self.view addSubview:_speakerButton];
    [self.view addSubview:_timerLabel];
    
    [_timerLabel setHidden:YES];//隐藏计时文本
    [self.timer setFireDate:[NSDate distantPast]];//先不开始计时
    
    linphone_core_set_native_video_window_id(_lc, (__bridge void *)(_lpcview));
    linphone_core_set_native_preview_window_id(_lc, (__bridge void *)(_lpview));
    linphone_core_video_enabled(_lc);
    linphone_core_video_preview_enabled(_lc);

    if (_calleeAccount == NULL) {//被叫接听视频通话
        LinphoneCallParams *cparams = linphone_core_create_call_params(_lc, _call);
        linphone_call_params_enable_video(cparams, true);
        linphone_call_params_enable_audio(cparams, true);
        linphone_call_accept_with_params(_call, cparams);
    } else {
        LinphoneCallParams *cparams = linphone_core_create_call_params(_lc, _call);
        linphone_call_enable_camera(_lc, true);
        linphone_call_params_enable_video(cparams, true);
        linphone_call_params_enable_audio(cparams, true);
        
        _call = linphone_core_invite_with_params(_lc, _calleeAccount, cparams);
        _lview.call = _call;
        
    }

    [super viewWillAppear:animated];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void) tapContainer:(id)sender {
    if (_hangupbtn.hidden){
        [_hangupbtn setHidden:NO];
    } else {
        [_hangupbtn setHidden:YES];
    }
    
    if (_micButton.hidden) {
        [_micButton setHidden:NO];
    } else {
        [_micButton setHidden:YES];
    }
    
    if (_speakerButton.hidden) {
        [_speakerButton setHidden:NO];
    } else {
        [_speakerButton setHidden:YES];
    }
    
    if (_timerLabel.hidden) {
        [_timerLabel setHidden:NO];
    } else {
        [_timerLabel setHidden:YES];
    }
}

-(void) tapPreview:(id)sender {
    const char *currentCamId = (char *)linphone_core_get_video_device(_lc);
    const char **cameras = linphone_core_get_video_devices(_lc);
    const char *newCamId = NULL;
    int i;
    
    for (i = 0; cameras[i] != NULL; ++i) {
        if (strcmp(cameras[i], "StaticImage: Static picture") == 0)
            continue;
        if (strcmp(cameras[i], currentCamId) != 0) {
            newCamId = cameras[i];
            break;
        }
    }
    if (newCamId) {
        linphone_core_set_video_device(_lc, newCamId);
        LinphoneCall *call = linphone_core_get_current_call(_lc);
        if (call != NULL) {
            linphone_call_update(call, NULL);
        }
    }
}

-(void)hangupEvt:(UIButton*)button
{
    [_hangupbtn setImage:[UIImage imageNamed:@"ring_on"] forState:UIControlStateNormal];
    if (_call != NULL) {
        linphone_call_terminate(_call);
    }
    _call = NULL;
    [self dismissViewControllerAnimated:YES completion:nil];
}
-(void)micEvt:(UIButton*)button
{
    AVAudioSession *sessionInstance = [AVAudioSession sharedInstance];
    BOOL success = FALSE;
    if(sessionInstance.isInputGainSettable) {
        if (_isMute) {
            _isMute = false;
            success = [sessionInstance setInputGain:0.0 error:nil];
            [_micButton setImage:[UIImage imageNamed:@"muteopen"] forState:UIControlStateNormal];
        } else {
            _isMute = true;
            success = [sessionInstance setInputGain:1.0 error:nil];
            [_micButton setImage:[UIImage imageNamed:@"muteclose"] forState:UIControlStateNormal];
        }
        
        if(success) {
            NSLog(@"Muted Successfully");
        } else {
            NSLog(@"An error occurred");
        }
    } else {
        NSLog(@"Not muted because this device does not allow changing inputGain");
        if (_isMute) {
            _isMute = false;
            [_micButton setImage:[UIImage imageNamed:@"muteopen"] forState:UIControlStateNormal];
        } else {
            _isMute = true;
            [_micButton setImage:[UIImage imageNamed:@"muteclose"] forState:UIControlStateNormal];
        }
    }
}
-(void)speakerEvt:(UIButton*)button
{
    AVAudioSession *sessionInstance = [AVAudioSession sharedInstance];
    BOOL success = FALSE;
    if (_isSpeaker) {
        _isSpeaker = false;
        [_speakerButton setImage:[UIImage imageNamed:@"speakerclose"] forState:UIControlStateNormal];
        success = [sessionInstance overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
    } else {
        _isSpeaker = true;
        [_speakerButton setImage:[UIImage imageNamed:@"speakeropen"] forState:UIControlStateNormal];
        success = [sessionInstance overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:nil];;
    }
    
    if(success) {
        NSLog(@"Turned On/Off Successfully");
    } else {
        NSLog(@"Turned speaker an error occurred");
    }
}

- (void)startTimer {
    _seconds++;
    total++;
    if (_seconds == 60) {
        _minutes++;
        _seconds = 0;
    }
    _timerLabel.text = [NSString stringWithFormat:@"%02d:%02d", _minutes, _seconds];
}

-(void)startTime {
    [_timerLabel setHidden:NO];
    [self.timer setFireDate:[NSDate distantPast]];
}

@end
