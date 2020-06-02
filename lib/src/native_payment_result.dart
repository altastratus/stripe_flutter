class NativePaymentResult {
  final bool isSuccess;
  final Map<String, dynamic> argument;

  NativePaymentResult(this.isSuccess, {this.argument})
      : assert(isSuccess != null, "isSuccess must not be null");
}
