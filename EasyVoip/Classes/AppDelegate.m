/*
 Licensed to the Apache Software Foundation (ASF) under one
 or more contributor license agreements.  See the NOTICE file
 distributed with this work for additional information
 regarding copyright ownership.  The ASF licenses this file
 to you under the Apache License, Version 2.0 (the
 "License"); you may not use this file except in compliance
 with the License.  You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing,
 software distributed under the License is distributed on an
 "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 KIND, either express or implied.  See the License for the
 specific language governing permissions and limitations
 under the License.
 */

//
//  AppDelegate.m
//  EasyVoip
//
//  Created by ___FULLUSERNAME___ on ___DATE___.
//  Copyright ___ORGANIZATIONNAME___ ___YEAR___. All rights reserved.
//

#import "AppDelegate.h"
#import "MainViewController.h"
#import "LinphoneManager.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)launchOptions
{
    
    LinphoneManager *instance = [LinphoneManager instance];
    //init logs asap
//    [Log enableLogs:[[LinphoneManager instance] lpConfigIntForKey:@"debugenable_preference"]];
    
    BOOL background_mode = [instance lpConfigBoolForKey:@"backgroundmode_preference"];
    BOOL start_at_boot = [instance lpConfigBoolForKey:@"start_at_boot_preference"];
    [LinphoneManager.instance startLinphoneCore];
    LinphoneManager.instance.iapManager.notificationCategory = @"expiry_notification";
    
    self.viewController = [[MainViewController alloc] init];
    return [super application:application didFinishLaunchingWithOptions:launchOptions];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
//    LOGI(@"%@", NSStringFromSelector(_cmd));
    [LinphoneManager.instance enterBackgroundMode];
    
}

- (void)applicationWillResignActive:(UIApplication *)application {
    //    LOGI(@"%@", NSStringFromSelector(_cmd));
    LinphoneCall *call = linphone_core_get_current_call(LC);
    
    if (!call)
    return;
    
    /* save call context */
    LinphoneManager *instance = LinphoneManager.instance;
    instance->currentCallContextBeforeGoingBackground.call = call;
    instance->currentCallContextBeforeGoingBackground.cameraIsEnabled = linphone_call_camera_enabled(call);
    
    const LinphoneCallParams *params = linphone_call_get_current_params(call);
    if (linphone_call_params_video_enabled(params))
    linphone_call_enable_camera(call, false);
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    //    LOGI(@"%@", NSStringFromSelector(_cmd));
    
    
    LinphoneManager *instance = LinphoneManager.instance;
    [instance becomeActive];
    
    if (instance.fastAddressBook.needToUpdate) {
        //Update address book for external changes
        
        [instance.fastAddressBook fetchContactsInBackGroundThread];
        instance.fastAddressBook.needToUpdate = FALSE;
        const MSList *lists = linphone_core_get_friends_lists(LC);
        while (lists) {
            linphone_friend_list_update_subscriptions(lists->data);
            lists = lists->next;
        }
    }
    
    LinphoneCall *call = linphone_core_get_current_call(LC);
    
    if (call) {
        if (call == instance->currentCallContextBeforeGoingBackground.call) {
            const LinphoneCallParams *params =
            linphone_call_get_current_params(call);
            if (linphone_call_params_video_enabled(params)) {
                linphone_call_enable_camera(
                                            call, instance->currentCallContextBeforeGoingBackground
                                            .cameraIsEnabled);
            }
            instance->currentCallContextBeforeGoingBackground.call = 0;
        } else if (linphone_call_get_state(call) ==
                   LinphoneCallIncomingReceived) {
            LinphoneCallAppData *data =
            (__bridge LinphoneCallAppData *)linphone_call_get_user_data(
                                                                        call);
            if (data && data->timer) {
                [data->timer invalidate];
                data->timer = nil;
            }
            if ((floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_9_x_Max)) {
                if ([LinphoneManager.instance lpConfigBoolForKey:@"autoanswer_notif_preference"]) {
                    linphone_call_accept(call);
                    //                    [PhoneMainView.instance changeCurrentView:CallView.compositeViewDescription];
                } else {
                    //                    [PhoneMainView.instance displayIncomingCall:call];
                }
            } else if (linphone_core_get_calls_nb(LC) > 1) {
                //                [PhoneMainView.instance displayIncomingCall:call];
            }
            
            // in this case, the ringing sound comes from the notification.
            // To stop it we have to do the iOS7 ring fix...
            //            [self fixRing];
        }
    }
    [LinphoneManager.instance.iapManager check];
    //    if (_shortcutItem) {
    //        [self handleShortcut:_shortcutItem];
    //        _shortcutItem = nil;
    //    }
    //    [HistoryListTableView saveDataToUserDefaults];
    //    [ChatsListTableView saveDataToUserDefaults];
}

@end
