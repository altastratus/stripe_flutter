class PaymentSummaryItemModel {
  /// a text to describe an item
  final String label;

  /// a value as a price, it can be a negative value to show as discount price
  final double amount;

  PaymentSummaryItemModel(this.label, this.amount);
}
