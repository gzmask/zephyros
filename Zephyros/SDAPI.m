//
//  SDAPI.m
//  Zephyros
//
//  Created by Steven on 4/15/13.
//  Copyright (c) 2013 Giant Robot Software. All rights reserved.
//

#import "SDAPI.h"

#import "SDWindowProxy.h"
#import "SDScreenProxy.h"

#import "SDConfigLauncher.h"

#import "SDAlertWindowController.h"
#import "SDLogWindowController.h"

#import "SDFuzzyMatcher.h"

@implementation SDAPISettings

- (id) init {
    if (self = [super init]) {
        self.alertDisappearDelay = 1.0;
        self.alertAnimates = YES;
    }
    return self;
}

- (BOOL) alertAnimates {
    return [SDAlertWindowController sharedAlertWindowController].alertAnimates;
}

- (void) setAlertAnimates:(BOOL)alertAnimates {
    [SDAlertWindowController sharedAlertWindowController].alertAnimates = alertAnimates;
}

- (NSBox*) alertBox {
    return [SDAlertWindowController sharedAlertWindowController].box;
}

- (NSTextField*) alertTextField {
    return [SDAlertWindowController sharedAlertWindowController].textField;
}

@end

@implementation SDAPI

+ (SDAPISettings*) settings {
    static SDAPISettings* settings;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        settings = [[SDAPISettings alloc] init];
    });
    return settings;
}

+ (void) chooseFrom:(NSArray*)list
              title:(NSString*)title
              lines:(NSNumber*)linesTall
              chars:(NSNumber*)charsWide
           callback:(void(^)(id idx))callback
{
    [NSApp activateIgnoringOtherApps:YES];
    [SDFuzzyMatcher showChoices:list
                      charsWide:[charsWide intValue]
                      linesTall:[linesTall intValue]
                    windowTitle:title
                  choseCallback:^(long chosenIndex) {
                      [NSApp hide:self];
                      callback(@(chosenIndex));
                  }
               canceledCallback:^{
                   [NSApp hide:self];
                   callback([NSNull null]);
               }];
}

+ (NSDictionary*) shell:(NSString*)cmd args:(NSArray*)args options:(NSDictionary *)options {
    BOOL doNotWait = NO;
    NSPipe* outPipe = [NSPipe pipe];
    NSPipe* errPipe = [NSPipe pipe];
    NSPipe* inPipe = [NSPipe pipe];
    
    NSString* pwd = [options objectForKey:@"pwd"];
    NSString* input = [options objectForKey:@"input"];
    NSValue* doNotWaitOption = [options objectForKey:@"donotwait"];
    if ([doNotWaitOption isKindOfClass:[NSValue class]]) {
        [doNotWaitOption getValue:&doNotWait];
    }
    
    if (input) {
        [[inPipe fileHandleForWriting] writeData:[input dataUsingEncoding:NSUTF8StringEncoding]];
        [[inPipe fileHandleForWriting] closeFile];
    }
    
    NSTask* task = [[NSTask alloc] init];
    task.launchPath = cmd;
    task.arguments = args;
    if (pwd)
        task.currentDirectoryPath = pwd;
    task.standardInput = inPipe;
    task.standardOutput = outPipe;
    task.standardError = errPipe;
  
    if (doNotWait) {
        [[outPipe fileHandleForReading] waitForDataInBackgroundAndNotify];
        [task launch];
        return @{};
    }
        
    [task launch];
    [task waitUntilExit];
    
    NSData* stdoutData = [[outPipe fileHandleForReading] readDataToEndOfFile];
    NSString* stdoutString = [[NSString alloc] initWithData:stdoutData encoding:NSUTF8StringEncoding];
    
    NSData* stderrData = [[errPipe fileHandleForReading] readDataToEndOfFile];
    NSString* stderrString = [[NSString alloc] initWithData:stderrData encoding:NSUTF8StringEncoding];
    
    return @{@"status": @([task terminationStatus]),
             @"stdout": stdoutString,
             @"stderr": stderrString};
}

@end
