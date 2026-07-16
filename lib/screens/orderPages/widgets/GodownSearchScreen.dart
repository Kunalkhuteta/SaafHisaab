import 'package:flutter/material.dart';

class GodownSearchScreen extends StatefulWidget {
  final List<Map<String, dynamic>> godowns;

  const GodownSearchScreen({
    super.key,
    required this.godowns,
  });

  @override
  State<GodownSearchScreen> createState() => _GodownSearchScreenState();
}

class _GodownSearchScreenState extends State<GodownSearchScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  late List<Map<String, dynamic>> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.godowns;

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
      _filtered = widget.godowns.where((g) {
        final name = (g['AcName'] ?? '').toString().toLowerCase();
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
        title: const Text(
          'Select Godown',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade700,
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search godown...',
                hintStyle: TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.search, color: Colors.white),
                filled: true,
                fillColor: Colors.white.withOpacity(0.2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _onSearch,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final godown = _filtered[i];
                return ListTile(
                  title: Text(godown['AcName'] ?? ''),
                  onTap: () => Navigator.pop(context, godown),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
