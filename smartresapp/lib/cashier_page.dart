import 'dart:async';

import 'package:flutter/material.dart';

import 'cashier_history_page.dart';
import 'invoice_dialog.dart';
import 'invoice_document.dart';
import 'ready_alert.dart';
import 'restaurant_theme.dart';
import 'staff_api.dart';
import 'table_status.dart';

class CashierPage extends StatefulWidget {
  final StaffApi? api;
  final bool autoRefresh;
  const CashierPage({super.key, this.api, this.autoRefresh = true});
  @override
  State<CashierPage> createState() => _CashierPageState();
}

class _CashierPageState extends State<CashierPage> {
  late final StaffApi api;
  List<Map<String, dynamic>> tables = [];
  Timer? timer;
  bool loading = true, fetching = false;
  String? error;
  String area = 'Tất cả', query = '';
  final paymentAlert = ReadyAlert();
  String requestKey(Map<String, dynamic> table) =>
      '${table['tableId']}:${table['openedAt']}';
  List<Map<String, dynamic>> get paymentRequests =>
      tables.where((t) => t['status'] == 'waiting_payment').toList();

  @override
  void initState() {
    super.initState();
    api = widget.api ?? StaffApi();
    load();
    if (widget.autoRefresh) {
      timer = Timer.periodic(const Duration(seconds: 5), (_) => load());
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    if (widget.api == null) api.client.close();
    super.dispose();
  }

  Future<void> load() async {
    if (fetching) return;
    fetching = true;
    try {
      final data = await api.cashierTables();
      if (!mounted) return;
      final previousRequests = paymentRequests.map(requestKey).toSet();
      final wasLoaded = !loading;
      setState(() {
        tables = (data['tables'] as List).cast<Map<String, dynamic>>();
        if (!tables.any((t) => t['area'] == area)) area = 'Tất cả';
        error = null;
        loading = false;
      });
      final incoming = paymentRequests
          .where((t) => !previousRequests.contains(requestKey(t)))
          .toList();
      if (incoming.isNotEmpty) unawaited(paymentAlert.play());
      if (wasLoaded && incoming.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Bàn ${incoming.map((t) => t['tableCode']).join(', ')} yêu cầu thanh toán.',
            ),
            action: SnackBarAction(
              label: 'Xem',
              onPressed: showPaymentRequests,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          loading = false;
        });
      }
    } finally {
      fetching = false;
    }
  }

  Future<void> showPaymentRequests() async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final requests = paymentRequests;
    if (requests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có yêu cầu thanh toán.')),
      );
      return;
    }
    if (requests.length == 1) {
      await openTable(requests.single);
      return;
    }
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Yêu cầu thanh toán',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            for (final table in requests)
              ListTile(
                leading: const Icon(
                  Icons.notifications_active_outlined,
                  color: brandOrange,
                ),
                title: Text('Bàn ${table['tableCode']}'),
                subtitle: Text('${table['area']} · ${table['guests']} khách'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    Navigator.pop(sheetContext, table['tableId'] as int),
              ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null) return;
    final current = paymentRequests.where((t) => t['tableId'] == selected);
    if (current.isNotEmpty) await openTable(current.first);
  }

  Future<void> openTable(Map<String, dynamic> table) async {
    if (table['hasInvoice'] == true && table['status'] != 'available') {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => InvoiceDialog(
          api: api,
          tableId: table['tableId'] as int,
          tableInfo: table,
          onUpdated: load,
          onPaid: (_) => load(),
        ),
      );
    } else {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Bàn ${table['tableCode']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${tableStatus(table['status'] as String)} · ${table['area']}',
              ),
              Text('${table['guests']} khách · ${table['seats']} chỗ'),
              if (table['openedAt'] != null)
                Text('Nhận bàn: ${invoiceDate(table['openedAt'])}'),
              const SizedBox(height: 16),
              Text(
                table['status'] == 'available'
                    ? 'Bàn đang trống, chưa có hóa đơn thanh toán.'
                    : 'Bàn chưa có món gọi, chưa có hóa đơn thanh toán.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    }
    if (mounted) await load();
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
              'Sơ đồ bàn',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Yêu cầu thanh toán',
            onPressed: showPaymentRequests,
            icon: Badge(
              label: Text('${paymentRequests.length}'),
              isLabelVisible: paymentRequests.isNotEmpty,
              child: const Icon(Icons.notifications_none),
            ),
          ),
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => CashierHistoryPage(api: api),
              ),
            ),
            icon: const Icon(Icons.history),
            label: const Text('Lịch sử'),
          ),
          IconButton(
            tooltip: 'Tải lại sơ đồ bàn',
            onPressed: load,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: paymentRequests.isEmpty
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(84),
                child: MaterialBanner(
                  backgroundColor: const Color(0xFFFFF1D9),
                  leading: const Icon(
                    Icons.notifications_active_outlined,
                    color: brandOrange,
                  ),
                  content: Text(
                    '${paymentRequests.length} bàn yêu cầu thanh toán: ${paymentRequests.map((t) => t['tableCode']).join(', ')}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  actions: [
                    TextButton(
                      onPressed: showPaymentRequests,
                      child: const Text('Xem yêu cầu'),
                    ),
                  ],
                ),
              ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: RefreshIndicator(
                  onRefresh: load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    children: [
                      if (error != null)
                        MaterialBanner(
                          content: Text(
                            '$error Dữ liệu đang hiển thị có thể đã cũ.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: load,
                              child: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      const Text(
                        'Khu vực phục vụ',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          for (final status in [
                            'available',
                            'dining',
                            'waiting_payment',
                          ])
                            Text(
                              '● ${tableStatus(status)} (${tables.where((t) => t['status'] == status).length})',
                              style: TextStyle(
                                color: tableStatusColor(status),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final a in [
                            'Tất cả',
                            ...tables.map((t) => t['area'] as String).toSet(),
                          ])
                            ChoiceChip(
                              label: Text(a),
                              selected: area == a,
                              onSelected: (_) => setState(() => area = a),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        onChanged: (value) => setState(() => query = value),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Tìm bàn, ví dụ A03',
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Chọn bàn để xem chi tiết và hóa đơn thanh toán.',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      const SizedBox(height: 14),
                      LayoutBuilder(
                        builder: (context, size) {
                          final visible = tables
                              .where(
                                (t) =>
                                    (area == 'Tất cả' || t['area'] == area) &&
                                    matchesSearch(
                                      t['tableCode'] as String,
                                      query,
                                    ),
                              )
                              .toList();
                          if (visible.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                tables.isEmpty
                                    ? 'Chưa có bàn để hiển thị.'
                                    : 'Không tìm thấy bàn phù hợp.',
                              ),
                            );
                          }
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: size.maxWidth > 650 ? 4 : 2,
                                  mainAxisExtent: 158,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                            itemCount: visible.length,
                            itemBuilder: (_, index) {
                              final table = visible[index];
                              final color = tableStatusColor(
                                table['status'] as String,
                              );
                              return Card(
                                key: ValueKey(
                                  'cashier-table-${table['tableId']}',
                                ),
                                color: Colors.white,
                                elevation: 0,
                                margin: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  side: BorderSide(
                                    color: color.withValues(alpha: .22),
                                  ),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: () => openTable(table),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                table['tableCode'] as String,
                                                style: const TextStyle(
                                                  fontSize: 23,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                            Icon(
                                              Icons.table_restaurant_outlined,
                                              color: color,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          tableStatus(
                                            table['status'] as String,
                                          ),
                                          style: TextStyle(
                                            color: color,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          '${table['area']} · ${table['guests'] == 0 ? '${table['seats']} chỗ' : '${table['guests']} khách'}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
    ),
  );
}
