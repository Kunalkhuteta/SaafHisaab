import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'globalVar.dart';

class SysParamNotifier extends Notifier<SysParamState> {
  @override
  SysParamState build() {
    return SysParamState(
      showNumber: prefs.getBool('sysParam_showNumber') ?? true,
      showGst: prefs.getBool('sysParam_showGst') ?? true,
      showPendingAmount: prefs.getBool('sysParam_showPendingAmount') ?? true,
      showStock: prefs.getBool('sysParam_showStock') ?? true,
      showStation: prefs.getBool('sysParam_showStation') ?? true,
      showAddress: prefs.getBool('sysParam_showAddress') ?? true,
      showItemCategory: prefs.getBool('sysParam_showItemCategory') ?? false,
      showItemGroup: prefs.getBool('sysParam_showItemGroup') ?? false,
    );
  }

  void setParam({
    bool? showNumber,
    bool? showGst,
    bool? showPendingAmount,
    bool? showStock,
    bool? showStation,
    bool? showAddress,
    bool? showItemCategory,
    bool? showItemGroup,
  }) {
    final newState = state.copyWith(
      showNumber: showNumber,
      showGst: showGst,
      showPendingAmount: showPendingAmount,
      showStock: showStock,
      showStation: showStation,
      showAddress: showAddress,
      showItemCategory: showItemCategory,
      showItemGroup: showItemGroup,
    );

    if (showNumber != null) prefs.setBool('sysParam_showNumber', showNumber);
    if (showGst != null) prefs.setBool('sysParam_showGst', showGst);
    if (showPendingAmount != null) prefs.setBool('sysParam_showPendingAmount', showPendingAmount);
    if (showStock != null) prefs.setBool('sysParam_showStock', showStock);
    if (showStation != null) prefs.setBool('sysParam_showStation', showStation);
    if (showAddress != null) prefs.setBool('sysParam_showAddress', showAddress);
    if (showItemCategory != null) prefs.setBool('sysParam_showItemCategory', showItemCategory);
    if (showItemGroup != null) prefs.setBool('sysParam_showItemGroup', showItemGroup);

    state = newState;
  }
}

class SysParamState {
  final bool showNumber;
  final bool showGst;
  final bool showPendingAmount;
  final bool showStock;
  final bool showStation;
  final bool showAddress;
  final bool showItemCategory;
  final bool showItemGroup;

  SysParamState({
    required this.showNumber,
    required this.showGst,
    required this.showPendingAmount,
    required this.showStock,
    required this.showStation,
    required this.showAddress,
    required this.showItemCategory,
    required this.showItemGroup,
  });

  SysParamState copyWith({
    bool? showNumber,
    bool? showGst,
    bool? showPendingAmount,
    bool? showStock,
    bool? showStation,
    bool? showAddress,
    bool? showItemCategory,
    bool? showItemGroup,
  }) {
    return SysParamState(
      showNumber: showNumber ?? this.showNumber,
      showGst: showGst ?? this.showGst,
      showPendingAmount: showPendingAmount ?? this.showPendingAmount,
      showStock: showStock ?? this.showStock,
      showStation: showStation ?? this.showStation,
      showAddress: showAddress ?? this.showAddress,
      showItemCategory: showItemCategory ?? this.showItemCategory,
      showItemGroup: showItemGroup ?? this.showItemGroup,
    );
  }
}

final sysParamProvider = NotifierProvider<SysParamNotifier, SysParamState>(SysParamNotifier.new);
