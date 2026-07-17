#import <Foundation/Foundation.h>

@interface ECVErrorLogBridge : NSObject

+ (instancetype)sharedBridge;
- (void)logLevel:(NSUInteger)level format:(NSString *)format arguments:(va_list)arguments;

@end

extern NSString * const ECVErrorLogNotification;
extern NSString * const ECVErrorLogLevelKey;
extern NSString * const ECVErrorLogMessageKey;
