import 'package:flutter/material.dart';
import 'package:saafhisaab/services/general_service.dart';
import 'package:saafhisaab/services/app_cache.dart';
import 'package:saafhisaab/widgets/app_loader.dart';
import 'package:saafhisaab/services/global_data.dart';
import 'package:saafhisaab/screens/orderPages/salesOrder/createSalesOrderPage.dart';
import 'package:saafhisaab/screens/orderPages/widgets/PartySearchDialog.dart';
import 'package:saafhisaab/widgets/bottom_contact_bar.dart';

class ParentMenuPage extends StatefulWidget {
  final String orderType; // 'SALES' or 'PURCHASE'

  const ParentMenuPage({super.key, required this.orderType});

  @override
  State<ParentMenuPage> createState() => _ParentMenuPageState();
}

class _ParentMenuPageState extends State<ParentMenuPage> {
  int? selectedPartyId;
  String? selectedPartyName;
  String? selectedPartyGSTNo;

  List<Map<String, dynamic>> partyList = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadParties(); // always fetch fresh — no cache check on entry
  }

  @override
  void dispose() {
    // ✅ Clears on ALL exit paths: back button, swipe, pop, etc.
    AppCache.clearOrderTypeCache(widget.orderType);
    super.dispose();
  }

  Future<void> _loadParties() async {
    setState(() => loading = true);

    try {
      final spFlag = widget.orderType == 'SALES' ? 'SALE' : 'PURCHASE';

      final data = await GeneralService.getPartyList(
        clientRegId: GlobalData().clientRegId ?? 0,
        coSoftId: GlobalData().coSoftId ?? 0,
        SPflag: spFlag,
      );

      if (!mounted) return;

      if (widget.orderType == 'SALES') {
        partyList =
            data
                .where((p) => p['PtType'] == 'C' || p['PtType'] == 'B')
                .toList();
      } else {
        partyList =
            data
                .where((p) => p['PtType'] == 'S' || p['PtType'] == 'B')
                .toList();
      }

      // ✅ Store in cache so OrderFormPage and AddItemDialog can reuse it
      AppCache.setPartyList(widget.orderType, partyList);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading parties: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _openPartySearch() async {
    if (partyList.isEmpty) return;

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => PartySearchScreen(parties: partyList)),
    );

    if (result != null && mounted) {
      setState(() {
        selectedPartyId = result['PtAccountId'];
        selectedPartyName = result['PartyFullName'];
        selectedPartyGSTNo = result['GSTNo'];
      });
    }
  }

  String get _pageTitle {
    return widget.orderType == 'SALES'
        ? 'Create Sales Order'
        : 'Create Purchase Order';
  }

  String get _instructionText {
    return widget.orderType == 'SALES'
        ? 'Select a customer to create sales order'
        : 'Select a supplier to create purchase order';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(_pageTitle),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: const BottomContactBar(),
      body:
          loading
              ? const Center(child: AppLoader())
              : SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Instruction card
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue.shade100),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.blue.shade700,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _instructionText,
                                      style: TextStyle(
                                        color: Colors.blue.shade900,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Party selector card
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.person_outline,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          widget.orderType == 'SALES'
                                              ? 'Customer Selection'
                                              : 'Supplier Selection',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Divider(height: 1),
                                  InkWell(
                                    onTap: _openPartySearch,
                                    borderRadius: const BorderRadius.vertical(
                                      bottom: Radius.circular(12),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  selectedPartyName ??
                                                      'Tap to select party',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight:
                                                        selectedPartyName !=
                                                                null
                                                            ? FontWeight.w600
                                                            : FontWeight.normal,
                                                    color:
                                                        selectedPartyName !=
                                                                null
                                                            ? Colors.black87
                                                            : Colors
                                                                .grey
                                                                .shade500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(
                                            Icons.search,
                                            color: Colors.blue.shade600,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Bottom action button
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed:
                              selectedPartyId == null
                                  ? null
                                  : () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) => OrderFormPage(
                                              orderType: widget.orderType,
                                              initialPartyId: selectedPartyId,
                                              initialPartyName:
                                                  selectedPartyName,
                                              partyGSTNo: selectedPartyGSTNo,
                                            ),
                                      ),
                                    );
                                    // ✅ Reset selection so user starts fresh if they tap Continue again
                                    if (mounted) {
                                      setState(() {
                                        selectedPartyId = null;
                                        selectedPartyName = null;
                                        selectedPartyGSTNo = null;
                                      });
                                    }
                                  },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey.shade300,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Continue',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (selectedPartyId != null) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward, size: 20),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
