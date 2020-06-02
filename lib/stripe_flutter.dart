import 'dart:async';

import 'package:flutter/services.dart';
import 'package:stripe_flutter/src/card_source_model.dart';
import 'package:stripe_flutter/src/customer_session.dart';
import 'package:stripe_flutter/src/ephemeral_key_provider.dart';
import 'package:stripe_flutter/src/native_payment.dart';
import 'package:stripe_flutter/src/native_payment_context.dart';
import 'package:stripe_flutter/src/native_payment_result.dart';
import 'package:stripe_flutter/src/payment_summary_item_model.dart';

export 'package:stripe_flutter/src/card_source_model.dart';
export 'package:stripe_flutter/src/ephemeral_key_provider.dart';
export 'package:stripe_flutter/src/native_checkout_result.dart';
export 'package:stripe_flutter/src/native_payment_context.dart';
export 'package:stripe_flutter/src/native_payment_result.dart';
export 'package:stripe_flutter/src/payment_summary_item_model.dart';

class StripeFlutter {
  static const MethodChannel _channel = const MethodChannel('stripe_flutter');

  static void Function(Map<String, String>) onSourceSelected;

  static initialize(String publishableKey, {String appleMerchantIdentifier}) {
    _channel.invokeMethod("sendPublishableKey", {
      "publishableKey": publishableKey,
      "appleMerchantIdentifier": appleMerchantIdentifier
    });

    _channel.setMethodCallHandler(_methodCallHandler);
  }

  static Future<String> initCustomerSession(EphemeralKeyProvider provider) {
    CustomerSession.initCustomerSession(provider);
    return _channel.invokeMethod("initCustomerSession");
  }

  static endCustomerSession() {
    CustomerSession.endCustomerSession();
    _channel.invokeMethod("endCustomerSession");
  }

  static Future<CardSourceModel> showPaymentMethodsScreen() async {
    try {
      var sourceResult =
          await _channel.invokeMethod("showPaymentMethodsScreen");
      return _parseToCardSourceModel(sourceResult);
    } on PlatformException catch (_) {
      return null;
    }
  }

  static CardSourceModel _tryParseToCardSourceModel(raw) {
    try {
      return _parseToCardSourceModel(raw);
    } catch (e) {
      print(e);
      return null;
    }
  }

  static CardSourceModel _parseToCardSourceModel(raw) => CardSourceModel(
      raw["id"],
      raw["last4"],
      raw["brand"],
      raw["expiredYear"] is String
          ? int.tryParse(raw["expiredYear"]) ?? 0
          : raw["expiredYear"],
      raw["expiredMonth"] is String
          ? int.tryParse(raw["expiredMonth"]) ?? 0
          : raw["expiredMonth"],
      raw["type"]);

  static Future<dynamic> _methodCallHandler(MethodCall methodCall) async {
    switch (methodCall.method) {
      case 'getEphemeralKey':
        final params = methodCall.arguments;
        return await _getEphemeralKey(params["apiVersion"].toString());
      case 'doNativePaymentCheckout':
        final params = methodCall.arguments;
        var source;
        try {
          source = _tryParseToCardSourceModel(params);
        } catch (e) {
          print(e);
          source = null;
        }
        return await _doNativeCheckout(source);
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

  static Future<CardSourceModel> getDefaultSource() async {
    try {
      var sourceResult =
      await _channel.invokeMethod("getCustomerDefaultSource");
      if (sourceResult is String || sourceResult == null) return null;
      var source = _parseToCardSourceModel(sourceResult);
      return source;
    } catch (e) {
      return null;
    }
  }

  /// [items] will show on apple pay payment modal, last item will show with
  /// bigger size and black text color (as default from apple pay), you are able
  /// to use negative as amount value to show as discount price.
  ///
  /// [nativePaymentContext] used to call your checkout service and return what
  /// apple pay stripe (native) need to continue to process.
  ///
  /// this method not handle any exception or error, please handle when call it!
  static Future<NativePaymentResult> payUsingApplePay(
      List<PaymentSummaryItemModel> items,
      NativePaymentContext nativePaymentContext) async {
    var mappedItems = items.map((item) {
      return {
        "label": item.label,
        "amount": item.amount.toString(),
      };
    }).toList();
    NativePayment.setNativePaymentContext(nativePaymentContext);
    var result = await _channel.invokeMethod("payUsingApplePay", mappedItems);
    var argument =
    result["arg"] != null ? Map<String, dynamic>.from(result["arg"]) : null;
    return NativePaymentResult(result["success"], argument: argument);
  }

  static Future<Map<String, dynamic>> _doNativeCheckout(
      CardSourceModel source) async {
    try {
      final nativePayment = NativePayment.getInstance();
      var result =
      await nativePayment.nativePaymentContext.doNativeCheckout(source);
      return {
        "isSuccess": result.isSuccess,
        "clientSecret": result.secretClient,
        "errorMessage": result.errorMessage,
        "argument": result.argument,
      };
    } on ArgumentError catch (_) {
      return null;
    }
  }
}
