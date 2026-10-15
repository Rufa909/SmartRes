import 'package:flutter/material.dart';

import 'staff_api.dart';
import 'restaurant_theme.dart';

class CashierPage extends StatefulWidget {
  final StaffApi? api;
  final bool autoRefresh;
  const CashierPage({super.key, this.api, this.autoRefresh = true});
  @override
  State<CashierPage> createState() => _CashierPageState();
}

class _CashierPageState extends State<CashierPage> {
  late final StaffApi api;
  List<Map<String, dynamic>> bills = [];
  bool loading = true, saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    api = widget.api ?? StaffApi();
    load();
  }

  @override
  void dispose() {
    if (widget.api == null) api.client.close();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final data = await api.cashier();
      if (!mounted) return;
      setState(() {
        bills = (data['tables'] as List).cast<Map<String, dynamic>>();
        error = null;
        loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          loading = false;
        });
      }
    }
  }

  String money(num v) =>
      '${v.toInt().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')} đ';
  Future<void> pay(Map<String, dynamic> bill) async {
    String method = 'cash';
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Thanh toán bàn ${bill['tableCode']}'),
          content: DropdownButtonFormField<String>(
            initialValue: method,
            decoration: const InputDecoration(labelText: 'Phương thức'),
            items: const [
              DropdownMenuItem(value: 'cash', child: Text('Tiền mặt')),
              DropdownMenuItem(
                value: 'bank_transfer',
                child: Text('Chuyển khoản'),
              ),
              DropdownMenuItem(value: 'card', child: Text('Thẻ')),
            ],
            onChanged: (v) => setLocal(() => method = v!),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, method),
              child: const Text('Xác nhận'),
            ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => saving = true);
    try {
      await api.pay(bill['tableId'] as int, selected);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã thanh toán và trả bàn về trống.')),
        );
      }
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: restaurantTheme(),
    child: Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thu ngân',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Text(
              'Hóa đơn chờ thanh toán',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Tải lại hóa đơn',
            onPressed: load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (error != null)
                    MaterialBanner(
                      content: Text(error!),
                      actions: [
                        TextButton(
                          onPressed: load,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  if (error == null && bills.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(48),
                      child: Column(
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 56,
                            color: brandOrange,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Chưa có hóa đơn chờ thanh toán',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Khi nhân viên yêu cầu thanh toán, hóa đơn sẽ xuất hiện ở đây.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ...bills.map((bill) {
                    final pending = (bill['pendingItems'] as num).toInt();
                    return Card(
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Bàn ${bill['tableCode']}',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: brandOrange,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${bill['orderCount']} đơn',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${bill['guests']} khách · ${pending == 0 ? 'Món đã phục vụ hết' : 'Còn $pending món chưa phục vụ'}',
                            ),
                            const SizedBox(height: 14),
                            Text(
                              money(bill['totalAmount'] as num),
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 14),
                            FilledButton.icon(
                              onPressed: saving || pending > 0
                                  ? null
                                  : () => pay(bill),
                              icon: const Icon(Icons.payments_outlined),
                              label: Text(
                                pending > 0 ? 'Chờ phục vụ món' : 'Thanh toán',
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    ),
  );
}
