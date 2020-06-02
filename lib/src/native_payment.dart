import 'package:stripe_flutter/src/native_payment_context.dart';
import 'package:stripe_flutter/stripe_flutter.dart';

class NativePayment {
  static NativePayment _instance;

  static NativePayment getInstance() {
    if (_instance == null) {
      throw new ArgumentError(
          "Attempted to get instance of NativePaymentContext without initialization.");
    }
    return _instance;
  }

  static void setNativePaymentContext(
      NativePaymentContext nativePaymentContext) {
    _setInstance(new NativePayment._(nativePaymentContext));
  }

  static void _setInstance(NativePayment nativePayment) {
    _instance = nativePayment;
  }

  final NativePaymentContext _nativePaymentContext;

  NativePaymentContext get nativePaymentContext {
    return _nativePaymentContext;
  }

  NativePayment._(this._nativePaymentContext);
}
