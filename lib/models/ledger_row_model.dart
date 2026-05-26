class LedgerRow {
  final String particular;
  final double debit;
  final double credit;
  final double balance;

  LedgerRow({
    required this.particular,
    required this.debit,
    required this.credit,
    required this.balance,
  });

  factory LedgerRow.fromJson(Map<String, dynamic> json) {
    double d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    return LedgerRow(
      particular: json['particular']?.toString() ?? '',
      debit: d(json['debitamt']),
      credit: d(json['creditamt']),
      balance: d(json['balanceamt']),
    );
  }
}
