import 'package:flutter/material.dart';

class TransportSearchScreen extends StatefulWidget {
  final List<Map<String, dynamic>> transports;

  const TransportSearchScreen({
    super.key,
    required this.transports,
  });

  @override
  State<TransportSearchScreen> createState() =>
      _TransportSearchScreenState();
}

class _TransportSearchScreenState
    extends State<TransportSearchScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  late List<Map<String, dynamic>> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.transports;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    setState(() {
      final searchLower = query.toLowerCase();
      _filtered = widget.transports.where((t) {
        final name =
            (t['Name'] ?? t['TransportName'] ?? '')
                .toString()
                .toLowerCase();
        return name.contains(searchLower);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.blue.shade700,
        elevation: 0,
        title: const Text(
          'Select Transport',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search transport...',
                hintStyle:
                    TextStyle(color: Colors.white.withOpacity(0.7)),
                prefixIcon:
                    const Icon(Icons.search, color: Colors.white),
                suffixIcon:
                    _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear,
                                color: Colors.white),
                            onPressed: () {
                              _searchController.clear();
                              _onSearch('');
                            },
                          )
                        : null,
                filled: true,
                fillColor: Colors.white.withOpacity(0.2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              onChanged: _onSearch,
            ),
          ),

          Expanded(
            child: _filtered.isEmpty
                ? const Center(
                    child: Text(
                      'No transport found',
                      style:
                          TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) =>
                        Divider(
                      height: 1,
                      color: Colors.grey.shade200,
                      indent: 16,
                      endIndent: 16,
                    ),
                    itemBuilder: (_, i) {
                      final transport = _filtered[i];
                      final name =
                          transport['Name'] ??
                              transport['TransportName'] ??
                              'Unknown';

                      return InkWell(
                        onTap: () =>
                            Navigator.pop(
                                context, transport),
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color:
                                      Colors.blue.shade50,
                                  borderRadius:
                                      BorderRadius
                                          .circular(8),
                                ),
                                child: Icon(
                                  Icons.local_shipping,
                                  color: Colors
                                      .blue.shade700,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  name,
                                  style:
                                      const TextStyle(
                                    fontSize: 15,
                                    fontWeight:
                                        FontWeight.w600,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: Colors
                                    .grey.shade400,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
