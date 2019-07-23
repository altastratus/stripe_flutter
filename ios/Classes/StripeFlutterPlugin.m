#import "StripeFlutterPlugin.h"
#import <stripe_flutter/stripe_flutter-Swift.h>

@implementation StripeFlutterPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftStripeFlutterPlugin registerWithRegistrar:registrar];
}
@end
