import '../stripe_flutter.dart';

abstract class NativePaymentContext {
  /// [doNativeCheckout] is a function to call your service to do a checkout /
  /// create a new order
  ///
  /// [source] is a paymentMethod that returned from native ApplePayContext
  /// you can use [source.sourceId] as payment source id if your server need it
  ///
  /// [NativeCheckoutResult] is needed to continue or cancel payment process
  Future<NativeCheckoutResult> doNativeCheckout(CardSourceModel source);
}
