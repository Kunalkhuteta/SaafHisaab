import 'package:flutter/material.dart';
import '../../models/bill_model.dart';
import '../../models/sale_model.dart';
import '../../models/udhar_model.dart';

enum ChartRange { week, month, year, custom }
enum ChartTab { sale, purchase, returns, credit }
enum ChartType { line, bar, pie }

class ChartPoint {
  final String label;
  final String? subLabel;
  final double amount;
  const ChartPoint(this.label, this.amount, {this.subLabel});
}

class ChartBucket {
  final DateTime start;
  final DateTime end;
  final String label;
  final String? subLabel;
  const ChartBucket(this.start, this.end, this.label, {this.subLabel});
}

class ChartsData {
  final List<ChartPoint> sales;
  final List<ChartPoint> purchases;
  final List<ChartPoint> returns;
  final List<ChartPoint> credit;

  const ChartsData({
    required this.sales,
    required this.purchases,
    required this.returns,
    required this.credit,
  });

  factory ChartsData.empty() =>
      const ChartsData(sales: [], purchases: [], returns: [], credit: []);

  List<ChartPoint> seriesFor(ChartTab tab) {
    switch (tab) {
      case ChartTab.sale: return sales;
      case ChartTab.purchase: return purchases;
      case ChartTab.returns: return returns;
      case ChartTab.credit: return credit;
    }
  }

  factory ChartsData.from({
    required List<BillModel> bills,
    required List<SaleModel> sales,
    required List<UdharCustomerModel> receivables,
    required DateTimeRange range,
    required ChartRange rangeType,
  }) {
    final buckets = _makeBuckets(range, rangeType);
    final salePoints = _emptyPoints(buckets);
    final purchasePoints = _emptyPoints(buckets);
    final returnPoints = _emptyPoints(buckets);
    final creditPoints = _emptyPoints(buckets);

    for (final sale in sales) {
      _add(salePoints, buckets, sale.saleDate, sale.totalAmount);
    }
    for (final bill in bills) {
      if (bill.billType == 'sale' &&
          !sales.any((s) => s.billId == bill.id)) {
        _add(salePoints, buckets, bill.billDate, bill.amount);
      } else if (bill.billType == 'purchase') {
        _add(purchasePoints, buckets, bill.billDate, bill.amount);
      } else if (bill.billType == 'sale_return' ||
          bill.billType == 'purchase_return') {
        _add(returnPoints, buckets, bill.billDate, bill.amount);
      }
    }
    for (final customer in receivables) {
      _add(creditPoints, buckets, customer.createdAt, customer.totalDue);
    }

    return ChartsData(
      sales: salePoints,
      purchases: purchasePoints,
      returns: returnPoints,
      credit: creditPoints,
    );
  }

  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static List<ChartBucket> _makeBuckets(DateTimeRange range, ChartRange type) {
    switch (type) {
      case ChartRange.week:
        return _weekBuckets(range);
      case ChartRange.month:
        return _monthBuckets(range);
      case ChartRange.year:
        return _yearBuckets(range);
      case ChartRange.custom:
        return _customBuckets(range);
    }
  }

  static List<ChartBucket> _weekBuckets(DateTimeRange range) {
    final days = range.end.difference(range.start).inDays + 1;
    return List.generate(days.clamp(1, 7), (i) {
      final d = range.start.add(Duration(days: i));
      final dayIdx = (d.weekday - 1) % 7;
      return ChartBucket(d, d, _dayNames[dayIdx], subLabel: '${d.day}');
    });
  }

  static List<ChartBucket> _monthBuckets(DateTimeRange range) {
    final days = range.end.difference(range.start).inDays + 1;
    final month = _monthNames[range.start.month - 1];
    return List.generate(days, (i) {
      final d = range.start.add(Duration(days: i));
      return ChartBucket(d, d, '${d.day}', subLabel: '$month Days');
    });
  }

  static List<ChartBucket> _yearBuckets(DateTimeRange range) {
    final year = range.start.year;
    final now = DateTime.now();
    final maxMonth = (year == now.year) ? now.month : 12;
    return List.generate(maxMonth, (i) {
      final start = DateTime(year, i + 1, 1);
      final end = (i + 1 < 12)
          ? DateTime(year, i + 2, 0)
          : DateTime(year, 12, 31);
      return ChartBucket(start, end, _monthNames[i]);
    });
  }

  static List<ChartBucket> _customBuckets(DateTimeRange range) {
    final days = range.end.difference(range.start).inDays + 1;
    if (days <= 14) {
      return List.generate(days, (i) {
        final d = range.start.add(Duration(days: i));
        return ChartBucket(d, d, '${d.day}/${d.month}');
      });
    } else if (days <= 90) {
      final weekCount = (days / 7).ceil();
      return List.generate(weekCount, (i) {
        final s = range.start.add(Duration(days: i * 7));
        var e = s.add(const Duration(days: 6));
        if (e.isAfter(range.end)) e = range.end;
        return ChartBucket(s, e, '${s.day}/${s.month}');
      });
    } else {
      final months = <ChartBucket>[];
      var cursor = DateTime(range.start.year, range.start.month, 1);
      while (!cursor.isAfter(range.end)) {
        final mEnd = DateTime(cursor.year, cursor.month + 1, 0);
        final actualEnd = mEnd.isAfter(range.end) ? range.end : mEnd;
        months.add(ChartBucket(cursor, actualEnd, _monthNames[cursor.month - 1]));
        cursor = DateTime(cursor.year, cursor.month + 1, 1);
      }
      return months;
    }
  }

  static List<ChartPoint> _emptyPoints(List<ChartBucket> buckets) =>
      buckets.map((b) => ChartPoint(b.label, 0, subLabel: b.subLabel)).toList();

  static void _add(
    List<ChartPoint> points,
    List<ChartBucket> buckets,
    DateTime date,
    double amount,
  ) {
    final day = DateTime(date.year, date.month, date.day);
    for (var i = 0; i < buckets.length; i++) {
      final b = buckets[i];
      final s = DateTime(b.start.year, b.start.month, b.start.day);
      final e = DateTime(b.end.year, b.end.month, b.end.day);
      if (!day.isBefore(s) && !day.isAfter(e)) {
        points[i] = ChartPoint(points[i].label, points[i].amount + amount,
            subLabel: points[i].subLabel);
        return;
      }
    }
  }
}
