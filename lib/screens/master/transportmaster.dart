import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/general_service.dart';

/// ============================================================
/// MODEL
/// Mirrors the Angular "Transport Information" record
/// ============================================================
class TransporterModel {
  String? id; // Supabase UUID
  int? transporterId;
  String name;
  String contactPerson;
  String mobileNo;
  String phone1;
  String phone2;
  String address;
  String gstinNo;
  String panNo;

  TransporterModel({
    this.id,
    this.transporterId,
    this.name = '',
    this.contactPerson = '',
    this.mobileNo = '',
    this.phone1 = '',
    this.phone2 = '',
    this.address = '',
    this.gstinNo = '',
    this.panNo = '',
  });

  TransporterModel copyWith() => TransporterModel(
        id: id,
        transporterId: transporterId,
        name: name,
        contactPerson: contactPerson,
        mobileNo: mobileNo,
        phone1: phone1,
        phone2: phone2,
        address: address,
        gstinNo: gstinNo,
        panNo: panNo,
      );

  factory TransporterModel.fromJson(Map<String, dynamic> json) {
    return TransporterModel(
      id: json['dbUuid'] ?? json['id'],
      transporterId: json['TransporterId'] ?? json['TransportId'],
      name: json['Name'] ?? json['name'] ?? '',
      contactPerson: json['ContactPerson'] ?? json['contact_person'] ?? '',
      mobileNo: json['MobileNo'] ?? json['mobile_no'] ?? '',
      phone1: json['Phone1'] ?? json['phone1'] ?? '',
      phone2: json['Phone2'] ?? json['phone2'] ?? '',
      address: json['Address'] ?? json['address'] ?? '',
      gstinNo: json['GSTINNo'] ?? json['gstin_no'] ?? '',
      panNo: json['PanNo'] ?? json['pan_no'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'TransporterId': transporterId,
        'Name': name,
        'ContactPerson': contactPerson,
        'MobileNo': mobileNo,
        'Phone1': phone1,
        'Phone2': phone2,
        'Address': address,
        'GSTINNo': gstinNo,
        'PanNo': panNo,
      };
}

/// ============================================================
/// THEME TOKENS — kept local so this file drops into any project
/// ============================================================
class _T {
  static const label = Color(0xFF8A4B12); // brownish-orange label color
  static const save = Color(0xFF13A15A); // green
  static const reset = Color(0xFF1B2A55); // navy
  static const cancel = Color(0xFFEC1876); // pink/red
  static const border = Color(0xFFD8DCE3);
  static const headerBg = Color(0xFF6C7793);
}

/// ============================================================
/// LIST PAGE
/// ============================================================
class TransporterListPage extends StatefulWidget {
  const TransporterListPage({super.key});

  @override
  State<TransporterListPage> createState() => _TransporterListPageState();
}

class _TransporterListPageState extends State<TransporterListPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  final List<TransporterModel> _all = [];
  List<TransporterModel> _filtered = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_applyFilter);
    _refreshList();
  }

  Future<void> _refreshList() async {
    setState(() => _loading = true);
    try {
      final data = await GeneralService.getAllTransportData();
      setState(() {
        _all.clear();
        _all.addAll(data.map((e) => TransporterModel.fromJson(e)));
        _applyFilter();
      });
    } catch (e) {
      debugPrint('Error loading transporters: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? List.of(_all)
          : _all.where((t) => t.name.toLowerCase().contains(q)).toList();
    });
  }

  Future<void> _openForm({TransporterModel? existing}) async {
    final result = await showDialog<TransporterModel>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddTransporterDialog(existing: existing),
    );

    if (result == null) return;

    _refreshList();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: _T.save,
          content: Text(existing != null
              ? 'Transporter updated'
              : 'Transporter added'),
        ),
      );
    }
  }

  Future<void> _deleteTransporter(TransporterModel t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transporter'),
        content: Text('Are you sure you want to delete ${t.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: _T.cancel),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        if (t.id != null) {
          await GeneralService.deleteTransporterByIntId(t.transporterId ?? 0);
        }
        _refreshList();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: _T.cancel,
              content: Text('Transporter deleted'),
            ),
          );
        }
      } catch (e) {
        debugPrint('Delete error: $e');
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F8),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchAndActions(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filtered.isEmpty
                      ? const _EmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final t = _filtered[i];
                            return _TransporterCard(
                              transporter: t,
                              onTap: () => _openForm(existing: t),
                              onDelete: () => _deleteTransporter(t),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _T.save,
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Entry',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      color: Colors.white,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _T.headerBg.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.local_shipping_rounded,
                color: _T.headerBg, size: 26),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Transporter List',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E2433))),
                Text('Transport master · manage carriers',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndActions() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: 'Search transporter...',
          prefixIcon: const Icon(Icons.search, size: 20),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          filled: true,
          fillColor: const Color(0xFFF4F5F8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_shipping_outlined,
              size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          Text('No transporters found',
              style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class _TransporterCard extends StatelessWidget {
  final TransporterModel transporter;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _TransporterCard({
    required this.transporter,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _T.border),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _T.headerBg.withOpacity(0.12),
                child: Text(
                  transporter.name.isNotEmpty
                      ? transporter.name.substring(0, 1).toUpperCase()
                      : '?',
                  style: const TextStyle(
                      color: _T.headerBg, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(transporter.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 3),
                    if (transporter.gstinNo.isNotEmpty)
                      Text('GSTIN: ${transporter.gstinNo}',
                          style: TextStyle(
                              fontSize: 12.5, color: Colors.grey.shade600))
                    else if (transporter.mobileNo.isNotEmpty)
                      Text(transporter.mobileNo,
                          style: TextStyle(
                              fontSize: 12.5, color: Colors.grey.shade600))
                    else
                      Text('—',
                          style: TextStyle(
                              fontSize: 12.5, color: Colors.grey.shade400)),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.grey),
                onSelected: (v) {
                  if (v == 'edit') onTap();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ============================================================
/// ADD / EDIT DIALOG — mirrors the Angular "Transport Information"
/// modal: Name*, Contact Person, Mobile No., Phone #1, Phone #2,
/// Address, GSTIN No., Pan No. + Save / Reset / Cancel
/// ============================================================
class AddTransporterDialog extends StatefulWidget {
  final TransporterModel? existing;
  const AddTransporterDialog({super.key, this.existing});

  @override
  State<AddTransporterDialog> createState() => _AddTransporterDialogState();
}

class _AddTransporterDialogState extends State<AddTransporterDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _contactCtrl;
  late final TextEditingController _mobileCtrl;
  late final TextEditingController _phone1Ctrl;
  late final TextEditingController _phone2Ctrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _gstinCtrl;
  late final TextEditingController _panCtrl;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _contactCtrl = TextEditingController(text: e?.contactPerson ?? '');
    _mobileCtrl = TextEditingController(text: e?.mobileNo ?? '');
    _phone1Ctrl = TextEditingController(text: e?.phone1 ?? '');
    _phone2Ctrl = TextEditingController(text: e?.phone2 ?? '');
    _addressCtrl = TextEditingController(text: e?.address ?? '');
    _gstinCtrl = TextEditingController(text: e?.gstinNo ?? '');
    _panCtrl = TextEditingController(text: e?.panNo ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    _mobileCtrl.dispose();
    _phone1Ctrl.dispose();
    _phone2Ctrl.dispose();
    _addressCtrl.dispose();
    _gstinCtrl.dispose();
    _panCtrl.dispose();
    super.dispose();
  }

  void _reset() {
    final e = widget.existing;
    _formKey.currentState?.reset();
    _nameCtrl.text = e?.name ?? '';
    _contactCtrl.text = e?.contactPerson ?? '';
    _mobileCtrl.text = e?.mobileNo ?? '';
    _phone1Ctrl.text = e?.phone1 ?? '';
    _phone2Ctrl.text = e?.phone2 ?? '';
    _addressCtrl.text = e?.address ?? '';
    _gstinCtrl.text = e?.gstinNo ?? '';
    _panCtrl.text = e?.panNo ?? '';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final model = TransporterModel(
      id: widget.existing?.id,
      transporterId: widget.existing?.transporterId,
      name: _nameCtrl.text.trim(),
      contactPerson: _contactCtrl.text.trim(),
      mobileNo: _mobileCtrl.text.trim(),
      phone1: _phone1Ctrl.text.trim(),
      phone2: _phone2Ctrl.text.trim(),
      address: _addressCtrl.text.trim(),
      gstinNo: _gstinCtrl.text.trim(),
      panNo: _panCtrl.text.trim().toUpperCase(),
    );

    try {
      await GeneralService.addEditTransporter(model);
      if (!mounted) return;
      Navigator.of(context).pop(model);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: _T.cancel,
            content: Text('Error saving transporter: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final size = MediaQuery.of(context).size;
    final maxWidth = size.width < 640 ? size.width * 0.94 : 620.0;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: size.height * 0.88,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogHeader(isEdit),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _fieldRow([
                        _field(
                          label: 'Name',
                          required: true,
                          controller: _nameCtrl,
                          hint: 'Name',
                          textCapitalization: TextCapitalization.words,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Name cannot be blank'
                              : null,
                        ),
                        _field(
                          label: 'Contact Person',
                          controller: _contactCtrl,
                          hint: 'Contact Person',
                          textCapitalization: TextCapitalization.words,
                        ),
                      ]),
                      const SizedBox(height: 16),
                      _fieldRow([
                        _field(
                          label: 'Mobile No.',
                          controller: _mobileCtrl,
                          hint: 'Mobile No.',
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          validator: (v) => (v != null &&
                                  v.isNotEmpty &&
                                  v.length != 10)
                              ? 'Enter a valid 10-digit number'
                              : null,
                        ),
                        _field(
                          label: 'Phone #1',
                          controller: _phone1Ctrl,
                          hint: 'Phone #1',
                          keyboardType: TextInputType.phone,
                        ),
                        _field(
                          label: 'Phone #2',
                          controller: _phone2Ctrl,
                          hint: 'Phone #2',
                          keyboardType: TextInputType.phone,
                        ),
                      ]),
                      const SizedBox(height: 16),
                      _fieldRow([
                        _field(
                          label: 'Address',
                          controller: _addressCtrl,
                          hint: 'Address',
                          maxLines: 2,
                          fullWidth: true,
                        ),
                      ]),
                      const SizedBox(height: 16),
                      _fieldRow([
                        _field(
                          label: 'GSTIN No.',
                          controller: _gstinCtrl,
                          hint: 'GST IN',
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(15),
                          ],
                        ),
                        _field(
                          label: 'Pan No.',
                          controller: _panCtrl,
                          hint: 'PAN NO.',
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(10),
                          ],
                        ),
                      ]),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              _dialogActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dialogHeader(bool isEdit) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _T.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              isEdit ? 'Edit Transport Information' : 'Transport Information',
              style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E2433)),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, size: 22),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _dialogActions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _T.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _actionBtn(
            label: 'Save',
            color: _T.save,
            onTap: _saving ? null : _save,
            loading: _saving,
          ),
          const SizedBox(width: 12),
          _actionBtn(label: 'Reset', color: _T.reset, onTap: _reset),
          const SizedBox(width: 12),
          _actionBtn(
            label: 'Cancel',
            color: _T.cancel,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required String label,
    required Color color,
    VoidCallback? onTap,
    bool loading = false,
  }) {
    return SizedBox(
      height: 42,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9)),
        ),
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14.5)),
      ),
    );
  }

  /// Lays fields out responsively: side-by-side on wide dialogs,
  /// stacked on narrow ones — like the web modal's flex rows.
  Widget _fieldRow(List<Widget> fields) {
    if (fields.length == 1) return fields.first;
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 420;
        if (narrow) {
          return Column(
            children: [
              for (int i = 0; i < fields.length; i++) ...[
                fields[i],
                if (i != fields.length - 1) const SizedBox(height: 16),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < fields.length; i++) ...[
              Expanded(child: fields[i]),
              if (i != fields.length - 1) const SizedBox(width: 14),
            ],
          ],
        );
      },
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    String? hint,
    bool required = false,
    bool fullWidth = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    final field = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: const TextStyle(
                color: _T.label, fontWeight: FontWeight.w600, fontSize: 13.5),
            children: required
                ? const [
                    TextSpan(
                        text: ' *',
                        style: TextStyle(
                            color: Colors.red, fontWeight: FontWeight.w700))
                  ]
                : null,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          inputFormatters: inputFormatters,
          validator: validator,
          style: const TextStyle(fontSize: 14.5),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(color: _T.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(color: _T.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(color: _T.headerBg, width: 1.4),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(color: Colors.red, width: 1.4),
            ),
          ),
        ),
      ],
    );

    return fullWidth ? field : field;
  }
}