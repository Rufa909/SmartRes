import 'package:flutter/material.dart';

import 'staff_api.dart';
import 'promotion_management_page.dart';
import 'invoice_document.dart';

class DiscountManagementPage extends StatefulWidget {
  final StaffApi api;
  const DiscountManagementPage({super.key, required this.api});
  @override
  State<DiscountManagementPage> createState() => _DiscountManagementPageState();
}

class _DiscountManagementPageState extends State<DiscountManagementPage> {
  List<Map<String, dynamic>> discounts = [];
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => busy = true);
    try {
      final data = await widget.api.managedDiscountCodes();
      if (mounted) {
        setState(() {
          discounts = (data['discounts'] as List).cast<Map<String, dynamic>>();
          error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> edit([Map<String, dynamic>? p]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PromotionFormDialog(
        api: widget.api,
        discountCodeMode: true,
        promotion: p == null
            ? null
            : {
                ...p,
                'name': p['discountName'],
                'discountValue': p['discountType'] == 'percentage'
                    ? p['discountPercent']
                    : p['fixedAmount'],
                'minBillAmount': p['minOrderValue'],
              },
      ),
    );
    if (saved == true && mounted) {
      await load();
    }
  }

  Future<void> toggle(Map<String, dynamic> p, bool active) async {
    setState(() => busy = true);
    try {
      await widget.api.toggleDiscountCode(
        p['id'] as int,
        p['version'] as int,
        active,
      );
      if (mounted) {
        await load();
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Giảm giá'),
      actions: [
        IconButton(
          onPressed: busy ? null : load,
          icon: const Icon(Icons.refresh),
          tooltip: 'Tải lại',
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: busy ? null : () => edit(),
      icon: const Icon(Icons.add),
      label: const Text('Tạo mã giảm giá'),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            if (busy) const LinearProgressIndicator(),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
            const Text(
              'Mã giảm giá toàn hóa đơn',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Lượt sử dụng được ghi nhận khi thanh toán thành công. Giờ Việt Nam (GMT+7).',
            ),
            if (!busy && discounts.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Chưa có mã giảm giá.'),
              ),
            for (final p in discounts)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              p['discountName'] as String,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Switch(
                            value: p['isActive'] as bool,
                            onChanged: busy ? null : (v) => toggle(p, v),
                          ),
                        ],
                      ),
                      SelectableText(
                        p['discountCode'] as String,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange,
                        ),
                      ),
                      Text(
                        'Giảm ${p['discountType'] == 'percentage' ? '${p['discountPercent']}%' : invoiceMoney(p['fixedAmount'] as num)} · ${p['isActive'] == true ? 'Đang bật' : 'Mã bị khóa'}',
                      ),
                      Text(
                        'Đã dùng ${p['usedQuantity']}/${p['totalQuantity']} · Còn ${p['remainingQuantity']} lượt',
                      ),
                      Text(
                        'Đơn tối thiểu: ${invoiceMoney(p['minOrderValue'] as num)}',
                      ),
                      Text(
                        'Giảm tối đa: ${p['maxDiscountAmount'] == null ? 'Không giới hạn' : invoiceMoney(p['maxDiscountAmount'] as num)}',
                      ),
                      Text(promotionSchedule(p)),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: busy ? null : () => edit(p),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Sửa mã giảm giá'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
