//
//  main.m
//  ffmpegTest
//
//  Created by 伍陶陶 on 2016/10/26.
//  Copyright © 2016年 伍陶陶. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AppDelegate.h"
#import "WTVoiceObject.h"

int main(int argc, char * argv[]) {
    @autoreleasepool {
        NSString* appClass = @"WTVoiceObject";
        NSString* delegateClass = nil;
        int retVal = UIApplicationMain(argc, argv, appClass, delegateClass);
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
