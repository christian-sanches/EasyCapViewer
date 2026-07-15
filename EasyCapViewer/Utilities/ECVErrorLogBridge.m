#import "ECVErrorLogBridge.h"

NSString * const ECVErrorLogNotification = @"ECVErrorLogNotification";
NSString * const ECVErrorLogLevelKey = @"ECVErrorLogLevelKey";
NSString * const ECVErrorLogMessageKey = @"ECVErrorLogMessageKey";

@implementation ECVErrorLogBridge

+ (instancetype)sharedBridge {
    static ECVErrorLogBridge *bridge = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        bridge = [[self alloc] init];
    });
    return bridge;
}

- (void)logLevel:(NSUInteger)level format:(NSString *)format arguments:(va_list)arguments {
    NSString *message = [[NSString alloc] initWithFormat:format arguments:arguments];
    NSDictionary *userInfo = @{
        ECVErrorLogLevelKey: @(level),
        ECVErrorLogMessageKey: message
    };
    [[NSNotificationCenter defaultCenter] postNotificationName:ECVErrorLogNotification
                                                        object:self
                                                      userInfo:userInfo];
}

@end
