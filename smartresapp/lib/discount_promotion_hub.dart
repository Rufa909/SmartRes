import 'package:flutter/material.dart';

import 'staff_api.dart';
import 'restaurant_theme.dart';
import 'promotion_management_page.dart';
import 'cashier_history_page.dart';
import 'discount_management_page.dart';

class DiscountPromotionHub extends StatelessWidget {
  final StaffApi api;
  const DiscountPromotionHub({super.key, required this.api});
  Widget entry(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    Widget page,
  ) => Card(
    color: Colors.white,
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => page),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (subtitle.isNotEmpty) const SizedBox(height: 6),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Theme(
    data: restaurantTheme(),
    child: Scaffold(
      appBar: AppBar(title: const Text('Giảm giá và khuyến mãi')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              entry(
                context,
                'Khuyến mãi',
                'Tạo và quản lý chương trình, khung giờ áp dụng',
                Icons.campaign_outlined,
                brandOrange,
                PromotionManagementPage(api: api),
              ),
              entry(
                context,
                'Giảm giá',
                '',
                Icons.percent_outlined,
                const Color(0xFF3366CC),
                DiscountManagementPage(api: api),
              ),
              entry(
                context,
                'Các đơn đã áp dụng',
                'Hóa đơn đã thanh toán có giảm giá hoặc khuyến mãi',
                Icons.receipt_long_outlined,
                const Color(0xFF23886B),
                CashierHistoryPage(api: api, discountedOnly: true),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
