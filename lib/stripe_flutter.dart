import 'dart:async';

import 'package:flutter/services.dart';
import 'package:stripe_flutter/src/customer_session.dart';
import 'package:stripe_flutter/src/ephemeral_key_provider.dart';

export 'package:stripe_flutter/src/ephemeral_key_provider.dart';

class StripeFlutter {
  static const MethodChannel _channel = const MethodChannel('stripe_flutter');

  static initialize(String publishableKey) {
    _channel
        .invokeMethod("sendPublishableKey", {"publishableKey": publishableKey});
    
    _channel.setMethodCallHandler(_methodCallHandler);
  }

  static initCustomerSession(EphemeralKeyProvider provider) {
    CustomerSession.initCustomerSession(provider);
    _channel.invokeMethod("initCustomerSession");
  }

  static endCustomerSession() {
    CustomerSession.endCustomerSession();
    _channel.invokeMethod("endCustomerSession");
  }

  static showPaymentMethodsScreen() async {
    try {
      final start = DateTime.now().millisecondsSinceEpoch;
      print("Starting at: " + start.toString());
      await _channel.invokeMethod("showPaymentMethodsScreen");
      final end = DateTime.now().millisecondsSinceEpoch;
      print("Ends at: " + end.toString());
    } on PlatformException catch (e) {
      print(e);
    }
  }

  static Future<dynamic> _methodCallHandler(MethodCall methodCall) async {
    switch (methodCall.method) {
      case 'getEphemeralKey':
        final params = methodCall.arguments;
        return await _getEphemeralKey(params["apiVersion"].toString());
      default:
        throw new MissingPluginException();
    }
  }

  static Future<String> _getEphemeralKey(String apiVersion) async {
    try {
      final customerSession = CustomerSession.getInstance();
      return await customerSession.ephemeralKeyProvider
          .createEphemeralKey(apiVersion);
    } on ArgumentError catch (_) {
      return null;
    }
  }
}
