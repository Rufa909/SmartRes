import 'dart:async';

import 'package:flutter/material.dart';

import 'staff_api.dart';
import 'table_status.dart';

String _money(num value) =>
    '${value.toInt().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')} đ';
String _itemStatus(String status) => switch (status) {
  'preparing' => 'Chờ bếp',
  'cooking' => 'Đang nấu',
  'completed' => 'Chờ phục vụ',
  'served' => 'Đã phục vụ',
  _ => status,
};

class StaffTableDetails extends StatefulWidget {
  final StaffApi api;
  final Map<String, dynamic> table;
  final bool autoRefresh;
  final ValueChanged<Map<String, dynamic>> onSeat, onOrder, onPayment;
  const StaffTableDetails({
    super.key,
    required this.api,
    required this.table,
    required this.onSeat,
    required this.onOrder,
    required this.onPayment,
    this.autoRefresh = true,
  });
  @override
  State<StaffTableDetails> createState() => _StaffTableDetailsState();
}

class _StaffTableDetailsState extends State<StaffTableDetails> {
  late Map<String, dynamic> table;
  List<Map<String, dynamic>> items = [];
  Timer? timer;
  bool loading = true, refreshing = false;
  String? error;
  num subtotal = 0;

  @override
  void initState() {
    super.initState();
    table = widget.table;
    unawaited(refresh());
    if (widget.autoRefresh) {
      timer = Timer.periodic(const Duration(seconds: 5), (_) => refresh());
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    if (refreshing) return;
    setState(() => refreshing = true);
    try {
      final data = await widget.api.tableDetails(widget.table['id'] as int);
      if (!mounted) return;
      setState(() {
        table = data['table'] as Map<String, dynamic>;
        items = (data['items'] as List).cast<Map<String, dynamic>>();
        subtotal = data['subtotalAmount'] as num;
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          refreshing = false;
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = loading || refreshing || error != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Bàn ${table['code']}',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Tải lại chi tiết bàn',
                onPressed: refreshing ? null : refresh,
                icon: const Icon(Icons.refresh),
              ),
              IconButton(
                tooltip: 'Đóng chi tiết bàn',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Text(
            '${tableStatus(table['status'] as String)} · ${table['area']} · ${table['guests']} khách',
          ),
          if (refreshing && !loading) const LinearProgressIndicator(),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  Text(error!, style: const TextStyle(color: Colors.red)),
                  if (items.isNotEmpty)
                    const Text('Dữ liệu bên dưới có thể đã cũ.'),
                  TextButton(
                    onPressed: refreshing ? null : refresh,
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Text(
            'Món đã gọi (${items.fold<int>(0, (sum, item) => sum + (item['quantity'] as num).toInt())} phần)',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                ? Center(
                    child: Text(
                      error != null
                          ? 'Chưa tải được danh sách món.'
                          : table['status'] == 'available'
                          ? 'Bàn trống, chưa có món đã gọi.'
                          : 'Bàn chưa gọi món.',
                    ),
                  )
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 18),
                    itemBuilder: (_, index) {
                      final item = items[index];
                      final note = (item['note'] as String? ?? '').trim();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name'] as String,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              Text(
                                '${item['quantity']} × ${_money(item['unitPrice'] as num)}',
                              ),
                              Text(
                                _money(item['lineTotal'] as num),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _itemStatus(item['status'] as String),
                            style: TextStyle(
                              color: item['status'] == 'served'
                                  ? Colors.green
                                  : Colors.deepOrange,
                            ),
                          ),
                          if (note.isNotEmpty) Text('Ghi chú: $note'),
                          if (item['orderCode'] != null)
                            Text(
                              'Đơn ${item['orderCode']}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tạm tính món',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Flexible(
                child: Text(
                  _money(subtotal),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Text(
            'Chưa trừ giảm giá trên hóa đơn.',
            style: TextStyle(fontSize: 11, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          if (table['status'] == 'available')
            FilledButton.icon(
              onPressed: locked ? null : () => widget.onSeat(table),
              icon: const Icon(Icons.group_add),
              label: const Text('Nhận bàn'),
            ),
          if (table['status'] == 'dining') ...[
            FilledButton.icon(
              onPressed: locked ? null : () => widget.onOrder(table),
              icon: const Icon(Icons.add),
              label: const Text('Gọi thêm món'),
            ),
            OutlinedButton(
              onPressed: locked || items.isEmpty
                  ? null
                  : () => widget.onPayment(table),
              child: const Text('Yêu cầu thanh toán'),
            ),
          ],
          if (table['status'] == 'waiting_payment')
            const Text('Bàn đang chờ thu ngân thanh toán.'),
        ],
      ),
    );
  }
}
