import 'package:intl/intl.dart';

class IndianNumberFormat {
  /// Format number in Indian style (₹1,23,456.78)
  static String formatCurrency(dynamic number, {int decimals = 2}) {
    if (number == null) return '₹0.00';
    
    final double value = _toDouble(number);
    final formatter = NumberFormat('#,##,##0.${'0' * decimals}', 'en_IN');
    return '₹${formatter.format(value)}';
  }

  /// Format number without currency symbol (1,23,456.78)
  static String formatNumber(dynamic number, {int decimals = 2}) {
    if (number == null) return '0.00';
    
    final double value = _toDouble(number);
    final formatter = NumberFormat('#,##,##0.${'0' * decimals}', 'en_IN');
    return formatter.format(value);
  }

  /// Format quantity (1,234.567 - 3 decimals)
  static String formatQty(dynamic number) {
    return formatNumber(number, decimals: 3);
  }

  /// Format rate (1,234.5678 - 4 decimals)
  static String formatRate(dynamic number) {
    return formatNumber(number, decimals: 4);
  }

  /// Format amount (₹1,23,456.78 - 2 decimals)
  static String formatAmount(dynamic number) {
    return formatCurrency(number, decimals: 2);
  }

  /// Format weight (1,234.567 - 3 decimals)
  static String formatWeight(dynamic number) {
    return formatNumber(number, decimals: 3);
  }

  /// Convert various types to double
  static double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

/// Extension for easy formatting
extension IndianNumberExtension on num {
  String toIndianCurrency({int decimals = 2}) {
    return IndianNumberFormat.formatCurrency(this, decimals: decimals);
  }

  String toIndianNumber({int decimals = 2}) {
    return IndianNumberFormat.formatNumber(this, decimals: decimals);
  }

  String toIndianQty() {
    return IndianNumberFormat.formatQty(this);
  }

  String toIndianRate() {
    return IndianNumberFormat.formatRate(this);
  }

  String toIndianAmount() {
    return IndianNumberFormat.formatAmount(this);
  }
}