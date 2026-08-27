import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Data class that holds all transport form values.
/// Mirrors Angular's TransportForm fields (the 8 selected fields only).
class TransportDetailData {
  int? localTransportId;    // LTpId  – City Transport
  int? transportId;         // TpId   – Transport
  String grNo;              // EWGRNo – G.R. No
  String vehicleNo;         // TruckNo
  DateTime? grDate;         // EWGRDate
  int cases;                // TCase
  int? deliverAtStationId;  // DelvAt
  int? locationId;          // LocationId
  int? shipToStateId;       // ShiptoState

  TransportDetailData({
    this.localTransportId,
    this.transportId,
    this.grNo = '',
    this.vehicleNo = '',
    this.grDate,
    this.cases = 0,
    this.deliverAtStationId,
    this.locationId,
    this.shipToStateId,
  });

  /// Build a map suitable for merging into the SIHDR payload —
  /// mirrors Angular's InvoiceAllDataToSave.SIHDR.* assignments.
  Map<String, dynamic> toSIHDRMap() => {
        'LTransportId': localTransportId ?? 0,
        'TransportId': transportId ?? 0,
        'SICases': cases,
        'TRStationId': deliverAtStationId ?? 0,
        'LocationId': locationId ?? 0,
        'ShiptoState': shipToStateId ?? 0,
      };

  /// Build a map for the InvTranTbl payload.
  Map<String, dynamic> toInvTranMap(DateFormat fmt) => {
        'EWGRNo': grNo,
        'ViehicalNo': vehicleNo,
        'EWGRDate': grDate != null
            ? grDate!.toIso8601String()
            : '0001-01-01T00:00:00',
      };

  TransportDetailData copyWith({
    int? localTransportId,
    int? transportId,
    String? grNo,
    String? vehicleNo,
    DateTime? grDate,
    int? cases,
    int? deliverAtStationId,
    int? locationId,
    int? shipToStateId,
  }) =>
      TransportDetailData(
        localTransportId: localTransportId ?? this.localTransportId,
        transportId: transportId ?? this.transportId,
        grNo: grNo ?? this.grNo,
        vehicleNo: vehicleNo ?? this.vehicleNo,
        grDate: grDate ?? this.grDate,
        cases: cases ?? this.cases,
        deliverAtStationId: deliverAtStationId ?? this.deliverAtStationId,
        locationId: locationId ?? this.locationId,
        shipToStateId: shipToStateId ?? this.shipToStateId,
      );
}

/// Modal dialog that mirrors the Angular TransportModal.
/// Returns a [TransportDetailData] when the user taps Save,
/// or null when the user cancels.
class TransportDetailDialog extends StatefulWidget {
  /// Pre-existing values to pre-fill the form (edit mode / re-open).
  final TransportDetailData? initialData;

  /// Dropdown lists — same shape as Angular's arrays.
  final List<Map<String, dynamic>> transportList;       // TpId list
  final List<Map<String, dynamic>> localTransportList;  // LTpId list
  final List<Map<String, dynamic>> stationList;         // DelvAt list
  final List<Map<String, dynamic>> locationList;        // LocationId list
  final List<Map<String, dynamic>> stateList;           // ShiptoState list

  /// Whether to show City Transport field
  /// (mirrors Sysparamdata.SI_ReadLTransportId).
  final bool showLocalTransport;

  const TransportDetailDialog({
    super.key,
    this.initialData,
    required this.transportList,
    required this.localTransportList,
    required this.stationList,
    required this.locationList,
    required this.stateList,
    this.showLocalTransport = false,
  });

  @override
  State<TransportDetailDialog> createState() => _TransportDetailDialogState();
}

class _TransportDetailDialogState extends State<TransportDetailDialog> {
  final _formKey = GlobalKey<FormState>();
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  // ── Form state ───────────────────────────────────────────────────────────
  int? _localTransportId;
  int? _transportId;
  int? _deliverAtStationId;
  int? _locationId;
  int? _shipToStateId;
  DateTime? _grDate;
  int _cases = 0;

  final _grNoCtrl = TextEditingController();
  final _vehicleNoCtrl = TextEditingController();
  final _casesCtrl = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    if (d != null) {
      _localTransportId = d.localTransportId;
      _transportId = d.transportId;
      _deliverAtStationId = d.deliverAtStationId;
      _locationId = d.locationId;
      _shipToStateId = d.shipToStateId;
      _grDate = d.grDate;
      _cases = d.cases;
      _grNoCtrl.text = d.grNo;
      _vehicleNoCtrl.text = d.vehicleNo;
      _casesCtrl.text = d.cases.toString();
    }
  }

  @override
  void dispose() {
    _grNoCtrl.dispose();
    _vehicleNoCtrl.dispose();
    _casesCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Validate that the given int id actually exists in a list.
  /// Returns null if the value is null/0 or not found.
  int? _safeId(int? id, List<Map<String, dynamic>> list) {
    if (id == null || id == 0) return null;
    final found = list.any(
      (e) => (e['id'] as int?) == id || (e['Id'] as int?) == id,
    );
    return found ? id : null;
  }

  String _nameFromList(
    int? id,
    List<Map<String, dynamic>> list, {
    String labelKey = 'Name',
  }) {
    if (id == null) return 'Select';
    final m = list.firstWhere(
      (e) => (e['id'] as int?) == id || (e['Id'] as int?) == id,
      orElse: () => {},
    );
    return m.isNotEmpty ? (m[labelKey] ?? 'Unknown').toString() : 'Select';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _grDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _grDate = picked);
  }

  void _save() {
    _formKey.currentState!.save();
    final result = TransportDetailData(
      localTransportId: _localTransportId,
      transportId: _transportId,
      grNo: _grNoCtrl.text.trim(),
      vehicleNo: _vehicleNoCtrl.text.trim(),
      grDate: _grDate,
      cases: int.tryParse(_casesCtrl.text) ?? 0,
      deliverAtStationId: _deliverAtStationId,
      locationId: _locationId,
      shipToStateId: _shipToStateId,
    );
    Navigator.of(context).pop(result);
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── 1. City Transport (conditional) ─────────────────
                    if (widget.showLocalTransport) ...[
                      _buildLabel('City Transport'),
                      _buildSearchableDropdown(
                        hint: 'Select City Transport',
                        selectedId: _safeId(
                            _localTransportId, widget.localTransportList),
                        items: widget.localTransportList,
                        labelKey: 'Name',
                        onSelected: (id) =>
                            setState(() => _localTransportId = id),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // ── 2. Transport ────────────────────────────────────
                    _buildLabel('Transport'),
                    _buildSearchableDropdown(
                      hint: 'Select Transport',
                      selectedId: _safeId(_transportId, widget.transportList),
                      items: widget.transportList,
                      labelKey: 'Name',
                      onSelected: (id) =>
                          setState(() => _transportId = id),
                    ),
                    const SizedBox(height: 14),

                    // ── 3. G.R. No + Vehicle No ─────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('G.R. No'),
                              _buildTextField(
                                  controller: _grNoCtrl,
                                  hint: 'Enter G.R. No'),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Vehicle No'),
                              _buildTextField(
                                  controller: _vehicleNoCtrl,
                                  hint: 'Enter Vehicle No'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ── 4. GR Date + Cases ──────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('GR Date / Receipt Date'),
                              _buildDateField(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Cases'),
                              _buildTextField(
                                controller: _casesCtrl,
                                hint: '0',
                                keyboardType: TextInputType.number,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ── 5. Deliver At (Station) ─────────────────────────
                    _buildLabel('Deliver At'),
                    _buildSearchableDropdown(
                      hint: 'Select Station',
                      selectedId:
                          _safeId(_deliverAtStationId, widget.stationList),
                      items: widget.stationList,
                      labelKey: 'Name',
                      onSelected: (id) =>
                          setState(() => _deliverAtStationId = id),
                    ),
                    const SizedBox(height: 14),

                    // ── 6. Location ─────────────────────────────────────
                    _buildLabel('Location'),
                    _buildSearchableDropdown(
                      hint: 'Select Location',
                      selectedId:
                          _safeId(_locationId, widget.locationList),
                      items: widget.locationList,
                      labelKey: 'Name',
                      onSelected: (id) => setState(() => _locationId = id),
                    ),
                    const SizedBox(height: 14),

                    // ── 7. Ship To State ────────────────────────────────
                    _buildLabel('Ship To State'),
                    _buildSearchableDropdown(
                      hint: 'Select State',
                      selectedId:
                          _safeId(_shipToStateId, widget.stateList),
                      items: widget.stateList,
                      labelKey: 'StateName',
                      onSelected: (id) =>
                          setState(() => _shipToStateId = id),
                    ),
                    const SizedBox(height: 24),

                    // ── Action buttons ──────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(null),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 28, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 28, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sub-widgets ──────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.blue.shade700,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_shipping, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Transport Details',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 20),
            onPressed: () => Navigator.of(context).pop(null),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
      );

  Widget _buildTextField({
    required TextEditingController controller,
    String hint = '',
    TextInputType keyboardType = TextInputType.text,
  }) =>
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                BorderSide(color: Colors.blue.shade700, width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          isDense: true,
        ),
      );

  Widget _buildDateField() => InkWell(
        onTap: _pickDate,
        child: InputDecorator(
          decoration: InputDecoration(
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            isDense: true,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _grDate != null
                    ? _dateFormat.format(_grDate!)
                    : 'Select Date',
                style: TextStyle(
                  color: _grDate != null
                      ? Colors.black87
                      : Colors.grey.shade400,
                  fontSize: 13,
                ),
              ),
              Icon(Icons.calendar_today,
                  size: 16, color: Colors.blue.shade700),
            ],
          ),
        ),
      );

  /// A tappable field that opens an inline search-list dialog.
  /// Mirrors ng-select [searchable]="true" behaviour.
  Widget _buildSearchableDropdown({
    required String hint,
    required int? selectedId,
    required List<Map<String, dynamic>> items,
    required String labelKey,
    required ValueChanged<int?> onSelected,
  }) {
    final displayName = selectedId != null
        ? _nameFromList(selectedId, items, labelKey: labelKey)
        : null;

    return InkWell(
      onTap: () async {
        final picked = await showDialog<int>(
          context: context,
          builder: (_) => _SearchPickerDialog(
            items: items,
            labelKey: labelKey,
            title: hint,
            initialId: selectedId,
          ),
        );
        // picked == -1 means "clear"
        if (picked != null) {
          onSelected(picked == -1 ? null : picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          isDense: true,
          suffixIcon: selectedId != null
              ? IconButton(
                  icon:
                      const Icon(Icons.clear, size: 16, color: Colors.grey),
                  onPressed: () => onSelected(null),
                  padding: EdgeInsets.zero,
                )
              : Icon(Icons.arrow_drop_down,
                  color: Colors.blue.shade700),
        ),
        child: Text(
          displayName ?? hint,
          style: TextStyle(
            color: displayName != null
                ? Colors.black87
                : Colors.grey.shade400,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ── Internal search picker ────────────────────────────────────────────────

class _SearchPickerDialog extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final String labelKey;
  final String title;
  final int? initialId;

  const _SearchPickerDialog({
    required this.items,
    required this.labelKey,
    required this.title,
    this.initialId,
  });

  @override
  State<_SearchPickerDialog> createState() => _SearchPickerDialogState();
}

class _SearchPickerDialogState extends State<_SearchPickerDialog> {
  final _searchCtrl = TextEditingController();
  late List<Map<String, dynamic>> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.items;
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.toLowerCase();
      setState(() {
        _filtered = widget.items
            .where((e) => (e[widget.labelKey] ?? '')
                .toString()
                .toLowerCase()
                .contains(q))
            .toList();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close,
                      color: Colors.white, size: 18),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          // Search box
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search, size: 18),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 10),
                isDense: true,
              ),
            ),
          ),
          // List
          Expanded(
            child: ListView.builder(
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final item = _filtered[i];
                final id = (item['id'] ?? item['Id']) as int;
                final name = (item[widget.labelKey] ?? '').toString();
                final isSelected = id == widget.initialId;
                return ListTile(
                  dense: true,
                  title: Text(name,
                      style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.normal)),
                  trailing: isSelected
                      ? Icon(Icons.check,
                          color: Colors.blue.shade700, size: 18)
                      : null,
                  onTap: () => Navigator.pop(context, id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}