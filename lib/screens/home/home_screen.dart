import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Blue header
          Container(
            color: AppColors.primary,
            padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 12,
                left: 20, right: 20, bottom: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Namaste, Sharma ji 👋',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      const SizedBox(height: 2),
                      Text('Sharma General Store',
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.75))),
                    ],
                  ),
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.notifications_outlined,
                      color: Colors.white, size: 20),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats
                  Row(
                    children: [
                      Expanded(child: _statCard('₹4,280', 'Aaj ki sale',
                          Icons.trending_up_rounded, AppColors.primary)),
                      const SizedBox(width: 12),
                      Expanded(child: _statCard('₹1,240', 'Pending udhar',
                          Icons.people_outline_rounded, AppColors.warning)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _statCard('23', 'Bills aaj',
                          Icons.receipt_outlined, AppColors.success)),
                      const SizedBox(width: 12),
                      Expanded(child: _statCard('5', 'Low stock',
                          Icons.inventory_2_outlined, AppColors.error)),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Quick actions
                  const Text('Quick Actions',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    children: [
                      _quickAction(Icons.document_scanner_rounded,
                          'Bill\nScan', AppColors.primary),
                      _quickAction(Icons.add_circle_outline_rounded,
                          'Sale\nAdd', AppColors.success),
                      _quickAction(Icons.people_outline_rounded,
                          'Udhar', AppColors.warning),
                      _quickAction(Icons.inventory_2_outlined,
                          'Stock', AppColors.purple),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Recent bills
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Aaj ke Bills',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      TextButton(
                        onPressed: () {},
                        child: const Text('Sab dekho',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.primary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _billItem('Reliance Fresh', '2:30 PM', '₹840'),
                  _billItem('Metro Cash & Carry', '11:15 AM', '₹2,100'),
                  _billItem('Local Supplier', '9:00 AM', '₹340'),
                ],
              ),
            ),
          ),
        ],
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textHint,
        selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_rounded), label: 'Bills'),
          BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_rounded), label: 'Stock'),
          BottomNavigationBarItem(
              icon: Icon(Icons.people_rounded), label: 'Udhar'),
          BottomNavigationBarItem(
              icon: Icon(Icons.more_horiz_rounded), label: 'More'),
        ],
      ),
    );
  }

  Widget _statCard(String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color)),
                Text(label,
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickAction(IconData icon, String label, Color color) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _billItem(String name, String time, String amount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primaryBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.receipt_rounded,
                color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary)),
                Text(time,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Text(amount,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary)),
        ],
      ),
    );
  }
}