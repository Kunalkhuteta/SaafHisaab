import 'package:flutter/material.dart';

class BottomContactBar extends StatelessWidget {
  const BottomContactBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.blue.shade50,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.support_agent, size: 16, color: Colors.blue),
          SizedBox(width: 8),
          Text(
            'Need help? Contact SaafHisaab Support',
            style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
