class CardSourceModel {
  final String sourceId;
  final String last4;
  final String brand;
  final int expiredYear;
  final int expiredMonth;

  CardSourceModel(this.sourceId, this.last4, this.brand, this.expiredYear,
      this.expiredMonth);
}
