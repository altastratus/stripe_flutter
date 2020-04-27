enum PaymentType {
  card,
  applePay,
  googlePay
}

PaymentType getPaymentType(String type) {
  switch (type) {
    case "ApplePay":
      return PaymentType.applePay;
    case "GooglePay":
      return PaymentType.googlePay;
    default:
      return PaymentType.card;
  }
}

class CardSourceModel {
  final String sourceId;
  final String last4;
  final String brand;
  final int expiredYear;
  final int expiredMonth;
  final String type;
  PaymentType paymentType;

  CardSourceModel(this.sourceId, this.last4, this.brand, this.expiredYear,
      this.expiredMonth, this.type) {
    paymentType = getPaymentType(this.type);
  }
}
