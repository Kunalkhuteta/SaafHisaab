import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../constants/app_colors.dart';
import '../../globalVar.dart';
import '../../providers/app_providers.dart';
import '../../services/supabase_service.dart';
import 'ledger_monthly_view_page.dart';

class OutstandingLedger {
  final String accountId;
  final String name;
  final double dueAmount; // Negative = Receivable (debit/owing), Positive = Payable (credit/due)

  OutstandingLedger({
    required this.accountId,
    required this.name,
    required this.dueAmount,
  });
}

class LedgerPartySelectionPage extends ConsumerStatefulWidget {
  const LedgerPartySelectionPage({super.key});

  @override
  ConsumerState<LedgerPartySelectionPage> createState() =>
      _LedgerPartySelectionPageState();
}

class _LedgerPartySelectionPageState extends ConsumerState<LedgerPartySelectionPage>
    with SingleTickerProviderStateMixin {
  bool _loading = false;
  bool _isReceivable = true;
  bool _combinedOutstanding = false; // Default unticked

  List<OutstandingLedger> _parties = [];
  List<OutstandingLedger> _filteredParties = [];
  OutstandingLedger? _selectedParty;

  double _receivableTotal = 0;
  double _payableTotal = 0;

  final NumberFormat _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );
  final TextEditingController _searchController = TextEditingController();

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  static const Color _receivableColor = AppColors.success;
  static const Color _payableColor = AppColors.error;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadParties();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadParties() async {
    final shop = ref.read(shopProvider).value;
    if (shop == null) return;

    setState(() {
      _loading = true;
      _selectedParty = null;
      _filteredParties = [];
      _receivableTotal = 0;
      _payableTotal = 0;
    });
    _animController.reset();

    try {
      final List<OutstandingLedger> data = [];

      if (_combinedOutstanding) {
        // Fetch both customers and suppliers
        final customers = await SupabaseService.getAllUdharCustomers(shop.id);
        for (final c in customers) {
          if (c.totalDue > 0) {
            data.add(OutstandingLedger(
              accountId: c.id,
              name: c.customerName,
              dueAmount: -c.totalDue,
            ));
          }
        }

        final suppliers = await SupabaseService.getPurchasePartiesWithPending(shop.id);
        for (final s in suppliers) {
          final amt = (s['pending_amount'] as num?)?.toDouble() ?? 0.0;
          if (amt > 0) {
            data.add(OutstandingLedger(
              accountId: s['id'] as String,
              name: s['name'] as String? ?? '',
              dueAmount: amt,
            ));
          }
        }
      } else {
        if (_isReceivable) {
          final customers = await SupabaseService.getAllUdharCustomers(shop.id);
          for (final c in customers) {
            if (c.totalDue > 0) {
              data.add(OutstandingLedger(
                accountId: c.id,
                name: c.customerName,
                dueAmount: -c.totalDue,
              ));
            }
          }
        } else {
          final suppliers = await SupabaseService.getPurchasePartiesWithPending(shop.id);
          for (final s in suppliers) {
            final amt = (s['pending_amount'] as num?)?.toDouble() ?? 0.0;
            if (amt > 0) {
              data.add(OutstandingLedger(
                accountId: s['id'] as String,
                name: s['name'] as String? ?? '',
                dueAmount: amt,
              ));
            }
          }
        }
      }

      double receivable = 0;
      double payable = 0;
      for (final party in data) {
        if (party.dueAmount < 0) {
          receivable += party.dueAmount;
        } else {
          payable += party.dueAmount;
        }
      }

      if (!mounted) return;
      setState(() {
        _parties = data;
        _filteredParties = data;
        _receivableTotal = receivable.abs();
        _payableTotal = payable.abs();
        _loading = false;
      });
      _animController.forward();
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showSnack('Failed to load parties: $e', isError: true);
      }
    }
  }

  void _filterParties(String query) {
    setState(() {
      _filteredParties =
          query.isEmpty
              ? _parties
              : _parties
                  .where(
                    (p) => p.name.toLowerCase().contains(query.toLowerCase()),
                  )
                  .toList();
    });
  }

  void _onShow() {
    if (_selectedParty == null) {
      _showSnack('Please select a party first', isError: true);
      return;
    }

    // Determine if the selected party is a customer or supplier.
    // If combined outstanding is enabled, the dueAmount sign determines this:
    // Negative = customer (receivable), Positive = supplier (payable).
    final isPartyReceivable = _selectedParty!.dueAmount < 0;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => LedgerMonthlyViewPage(
              accountId: _selectedParty!.accountId,
              partyName: _selectedParty!.name,
              isReceivable: isPartyReceivable,
            ),
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade700 : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _openPartyPicker() {
    _searchController.clear();
    _filterParties('');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => _PartyPickerPage(
              parties: _parties,
              selectedParty: _selectedParty,
              isReceivable: _isReceivable,
              accentColor: _accentColor,
              currency: _currency,
              receivableTotal: _receivableTotal,
              payableTotal: _payableTotal,
              onSelected: (party) {
                setState(() => _selectedParty = party);
              },
            ),
      ),
    );
  }

  Color get _accentColor => _isReceivable ? _receivableColor : _payableColor;

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(appLanguageProvider);
    final now = DateTime.now();
    final fyStart = now.month >= 4 ? now.year : now.year - 1;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLang.tr(isEn, 'Ledger Party Selection', 'लेजर पार्टी चयन'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            Text(
              'FY $fyStart-${(fyStart + 1).toString().substring(2)}',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : FadeTransition(
                opacity: _fadeAnim,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _typeToggle(),
                      const SizedBox(height: 12),
                      _combinedOutstandingToggle(),
                      const SizedBox(height: 16),
                      _statsRow(),
                      const SizedBox(height: 24),
                      _partySelector(),
                      if (_selectedParty != null) ...[
                        const SizedBox(height: 16),
                        _selectedPartyCard(),
                      ],
                      const SizedBox(height: 28),
                      _showButton(),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _combinedOutstandingToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              _combinedOutstanding
                  ? AppColors.primary.withOpacity(0.4)
                  : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: (_combinedOutstanding ? AppColors.primary : Colors.grey)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.merge_type_rounded,
              size: 18,
              color: _combinedOutstanding ? AppColors.primary : Colors.grey,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Combined Outstanding',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  _combinedOutstanding ? 'Enabled' : 'Disabled',
                  style: TextStyle(
                    fontSize: 11,
                    color: _combinedOutstanding ? AppColors.primary : Colors.black38,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _combinedOutstanding,
            onChanged: (val) {
              setState(() => _combinedOutstanding = val);
              _loadParties();
            },
            activeColor: AppColors.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _typeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _toggleBtn(
            'Receivable',
            true,
            _receivableColor,
            Icons.call_received_rounded,
          ),
          _toggleBtn('Payable', false, _payableColor, Icons.call_made_rounded),
        ],
      ),
    );
  }

  Widget _toggleBtn(String label, bool value, Color color, IconData icon) {
    final isActive = _isReceivable == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_isReceivable == value) return;
          setState(() => _isReceivable = value);
          _loadParties();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isActive ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive ? Colors.white : Colors.grey,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isActive ? Colors.white : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statsRow() {
    final count = _parties.length;
    final total = _isReceivable ? _receivableTotal : _payableTotal;

    return Row(
      children: [
        Expanded(
          child: _statCard(
            'Parties',
            count.toString(),
            Icons.people_alt_rounded,
            AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            _isReceivable ? 'Total Receivable' : 'Total Payable',
            _currency.format(total),
            Icons.account_balance_wallet_rounded,
            _accentColor,
          ),
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Colors.black45),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _partySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Party',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _parties.isEmpty ? null : _openPartyPicker,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color:
                    _selectedParty != null
                        ? _accentColor
                        : Colors.grey.shade300,
                width: _selectedParty != null ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: (_selectedParty != null ? _accentColor : Colors.grey)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.storefront_rounded,
                    size: 18,
                    color: _selectedParty != null ? _accentColor : Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedParty?.name ?? 'Tap to select a party...',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          _selectedParty != null
                              ? FontWeight.w600
                              : FontWeight.w400,
                      color:
                          _selectedParty != null ? Colors.black87 : Colors.grey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: _selectedParty != null ? _accentColor : Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _selectedPartyCard() {
    final amt = _selectedParty!.dueAmount;
    final isPartyReceivable = amt < 0;
    final amtColor = isPartyReceivable ? _receivableColor : _payableColor;
    final label = isPartyReceivable ? 'Receivable' : 'Payable';
    
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _accentColor.withOpacity(0.08),
              _accentColor.withOpacity(0.03),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _accentColor.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: _accentColor.withOpacity(0.15),
              child: Text(
                _selectedParty!.name.isNotEmpty ? _selectedParty!.name[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _accentColor,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedParty!.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Outstanding Amount',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _currency.format(amt.abs()),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: amtColor,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: amtColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: amtColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _showButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _selectedParty != null ? _onShow : null,
        icon: const Icon(Icons.bar_chart_rounded, size: 20),
        label: const Text(
          'View Ledger',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              _selectedParty != null ? _accentColor : Colors.grey.shade400,
          foregroundColor: Colors.white,
          elevation: _selectedParty != null ? 4 : 0,
          shadowColor: _accentColor.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _PartyPickerPage extends StatefulWidget {
  final List<OutstandingLedger> parties;
  final OutstandingLedger? selectedParty;
  final bool isReceivable;
  final Color accentColor;
  final NumberFormat currency;
  final double receivableTotal;
  final double payableTotal;
  final ValueChanged<OutstandingLedger> onSelected;

  const _PartyPickerPage({
    required this.parties,
    required this.selectedParty,
    required this.isReceivable,
    required this.accentColor,
    required this.currency,
    required this.receivableTotal,
    required this.payableTotal,
    required this.onSelected,
  });

  @override
  State<_PartyPickerPage> createState() => _PartyPickerPageState();
}

class _PartyPickerPageState extends State<_PartyPickerPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<OutstandingLedger> _filtered = [];

  static const Color _receivableColor = AppColors.success;
  static const Color _payableColor = AppColors.error;

  @override
  void initState() {
    super.initState();
    _filtered = widget.parties;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filter(String q) {
    setState(() {
      _filtered =
          q.isEmpty
              ? widget.parties
              : widget.parties
                  .where((p) => p.name.toLowerCase().contains(q.toLowerCase()))
                  .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: widget.accentColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Select Party',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              onChanged: _filter,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                hintText: 'Search party...',
                hintStyle: const TextStyle(color: Colors.white60, fontSize: 14),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Colors.white70,
                  size: 20,
                ),
                suffixIcon:
                    _searchCtrl.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(
                            Icons.clear_rounded,
                            color: Colors.white70,
                            size: 18,
                          ),
                          onPressed: () {
                            _searchCtrl.clear();
                            _filter('');
                          },
                        )
                        : null,
                filled: true,
                fillColor: Colors.white.withOpacity(0.15),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: widget.accentColor.withOpacity(0.06),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Text(
                  '${_filtered.length} ${_filtered.length == 1 ? 'party' : 'parties'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: widget.accentColor,
                  ),
                ),
                const Spacer(),
                _totalBadge(
                  'Receivable',
                  widget.currency.format(widget.receivableTotal),
                  _receivableColor,
                ),
                const SizedBox(width: 8),
                _totalBadge(
                  'Payable',
                  widget.currency.format(widget.payableTotal),
                  _payableColor,
                ),
              ],
            ),
          ),

          Expanded(
            child:
                _filtered.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 56,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No parties found',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                      itemCount: _filtered.length,
                      separatorBuilder:
                          (_, __) =>
                              Divider(color: Colors.grey.shade200, height: 1),
                      itemBuilder: (_, i) {
                        final p = _filtered[i];
                        final isSelected = widget.selectedParty == p;
                        final amt = p.dueAmount;

                        final isPartyReceivable = amt < 0;
                        final amtColor = isPartyReceivable ? _receivableColor : _payableColor;
                        final amtLabel = isPartyReceivable ? 'Receivable' : 'Payable';

                        return ListTile(
                          onTap: () {
                            widget.onSelected(p);
                            Navigator.pop(context);
                          },
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          tileColor:
                              isSelected
                                  ? widget.accentColor.withOpacity(0.08)
                                  : Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 4,
                          ),
                          leading: CircleAvatar(
                            radius: 22,
                            backgroundColor:
                                isSelected
                                    ? widget.accentColor
                                    : widget.accentColor.withOpacity(0.1),
                            child: Text(
                              p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color:
                                    isSelected
                                        ? Colors.white
                                        : widget.accentColor,
                              ),
                            ),
                          ),
                          title: Text(
                            p.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight:
                                  isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    widget.currency.format(amt.abs()),
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: amtColor,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: amtColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      amtLabel,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: amtColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (isSelected) ...[
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: widget.accentColor,
                                  size: 20,
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _totalBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
