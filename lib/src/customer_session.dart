import 'package:stripe_flutter/src/ephemeral_key_provider.dart';
import 'package:stripe_flutter/stripe_flutter.dart';

class CustomerSession {
  static CustomerSession _instance;

  static CustomerSession getInstance() {
    if (_instance == null) {
      throw new ArgumentError(
          "Attempted to get instance of CustomerSession without initialization.");
    }
    return _instance;
  }

  static void initCustomerSession(EphemeralKeyProvider ephemeralKeyProvider) {
    _setInstance(new CustomerSession._(ephemeralKeyProvider));
  }

  static void endCustomerSession() {
    _clearInstance();
  }

  static void _setInstance(CustomerSession customerSession) {
    _instance = customerSession;
  }

  static void _clearInstance() {
    _setInstance(null);
  }

  final EphemeralKeyProvider _ephemeralKeyProvider;

  EphemeralKeyProvider get ephemeralKeyProvider {
    return _ephemeralKeyProvider;
  }

  CustomerSession._(this._ephemeralKeyProvider);
}
