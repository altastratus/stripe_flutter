import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:stripe_flutter/src/card_source_model.dart';
import 'package:stripe_flutter/src/customer_session.dart';
import 'package:stripe_flutter/src/ephemeral_key_provider.dart';
import 'package:stripe_flutter/src/payment_summary_item_model.dart';

export 'package:stripe_flutter/src/card_source_model.dart';
export 'package:stripe_flutter/src/ephemeral_key_provider.dart';
export 'package:stripe_flutter/src/payment_summary_item_model.dart';

class StripeFlutter {
  static const MethodChannel _channel = const MethodChannel('stripe_flutter');

  static void Function(Map<String, String>) onSourceSelected;

  static initialize(String publishableKey) {
    _channel
        .invokeMethod("sendPublishableKey", {"publishableKey": publishableKey});

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
      if (sourceResult is Map) print(json.encode(sourceResult));
      return _parseToCardSourceModel(sourceResult);
    } on PlatformException catch (e) {
      print(e);
      return null;
    }
  }

  static CardSourceModel _parseToCardSourceModel(raw) =>
      CardSourceModel(
        raw["id"],
        raw["last4"],
        raw["brand"],
        raw["expiredYear"] is String
            ? int.tryParse(raw["expiredYear"]) ?? 0
            : raw["expiredYear"],
        raw["expiredMonth"] is String
            ? int.tryParse(raw["expiredMonth"]) ?? 0
            : raw["expiredMonth"],
          raw["type"]
      );

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

  static Future<CardSourceModel> getSelectedPaymentMethod() async {
    var sourceResult = await _channel.invokeMethod("getSelectedPaymentOption");
    print("getSelectedPaymentOption $sourceResult");
    if (sourceResult == null || sourceResult is String) throw Exception(
        "Customer session must be initialized first");
    return _parseToCardSourceModel(sourceResult);
  }

  static Future payUsingApplePay(List<PaymentSummaryItemModel> items) async {
    var args = items.map((item) {
      return {
        "label": item.label,
        "amount": item.amount.toString(),
      };
    }).toList();
    var result = await _channel.invokeMethod("payUsingApplePay", args);
    print("apple pay result $result");
    return result;
  }
}
