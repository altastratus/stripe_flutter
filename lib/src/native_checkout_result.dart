class NativeCheckoutResult {
  final bool isSuccess;
  final String secretClient;
  final String errorMessage;
  final Map<String, String> argument;

  NativeCheckoutResult(this.isSuccess,
      {this.secretClient, this.errorMessage, this.argument})
      : assert(isSuccess != null, "isSuccess must not be null"),
        assert(
          isSuccess ? secretClient != null : errorMessage != null,
          isSuccess
              ? "secretClient must not be null when success"
              : "errorMessage must not be null when not success",
        );
}
