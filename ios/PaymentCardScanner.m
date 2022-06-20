#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(PaymentCardScanner, NSObject)

RCT_EXTERN_METHOD(scan: (NSString*)topText withBottomText: (NSString*)bottomText withTopTextFont: (NSString*)topTextFont withBottomTextFont: (NSString*)bottomTextFont withResolver:(RCTPromiseResolveBlock)resolve withRejecter:(RCTPromiseRejectBlock)reject)

+ (BOOL)requiresMainQueueSetup
{
  return NO;
}

@end
