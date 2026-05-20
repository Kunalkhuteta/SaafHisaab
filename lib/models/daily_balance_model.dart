class DailyBalanceModel {
  final String id;
  final String shopId;
  final DateTime balanceDate;
  
  final double cashIn;
  final double cashOut;
  final double bankIn;
  final double bankOut;
  
  final double netCash;
  final double netBank;

  DailyBalanceModel({
    required this.id,
    required this.shopId,
    required this.balanceDate,
    this.cashIn = 0,
    this.cashOut = 0,
    this.bankIn = 0,
    this.bankOut = 0,
    this.netCash = 0,
    this.netBank = 0,
  });

  factory DailyBalanceModel.fromJson(Map<String, dynamic> json) {
    return DailyBalanceModel(
      id: json['id'] ?? '',
      shopId: json['shop_id'] ?? '',
      balanceDate: DateTime.parse(json['balance_date']),
      cashIn: (json['cash_in'] ?? 0).toDouble(),
      cashOut: (json['cash_out'] ?? 0).toDouble(),
      bankIn: (json['bank_in'] ?? 0).toDouble(),
      bankOut: (json['bank_out'] ?? 0).toDouble(),
      netCash: (json['net_cash'] ?? 0).toDouble(),
      netBank: (json['net_bank'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shop_id': shopId,
      'balance_date': balanceDate.toIso8601String().split('T')[0],
      'cash_in': cashIn,
      'cash_out': cashOut,
      'bank_in': bankIn,
      'bank_out': bankOut,
      'net_cash': netCash,
      'net_bank': netBank,
    };
  }
}
