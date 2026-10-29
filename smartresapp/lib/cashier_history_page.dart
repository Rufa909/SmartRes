import 'package:flutter/material.dart';

import 'invoice_dialog.dart';
import 'invoice_document.dart';
import 'staff_api.dart';

class CashierHistoryPage extends StatefulWidget {
  final StaffApi api;
  const CashierHistoryPage({super.key, required this.api});
  @override
  State<CashierHistoryPage> createState() => _CashierHistoryPageState();
}

class _CashierHistoryPageState extends State<CashierHistoryPage> {
  final search = TextEditingController();
  List<Map<String, dynamic>> receipts = [];
  int offset = 0, total = 0;
  bool loading = true;
  String? error;
  int? opening;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> load({int pageOffset = 0}) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await widget.api.invoiceHistory(
        query: search.text.trim(),
        offset: pageOffset,
      );
      if (!mounted) return;
      setState(() {
        receipts = (data['invoices'] as List).cast<Map<String, dynamic>>();
        total = (data['total'] as num).toInt();
        offset = pageOffset;
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> open(Map<String, dynamic> receipt) async {
    if (opening != null) return;
    setState(() => opening = receipt['historyId'] as int);
    try {
      final invoice = await widget.api.savedInvoice(
        receipt['historyId'] as int,
      );
      if (!mounted) return;
      setState(() => opening = null);
      await showDialog<void>(
        context: context,
        builder: (_) => InvoiceDialog(
          api: widget.api,
          tableId: invoice['tableId'] as int,
          receipt: invoice,
          onPaid: (_) {},
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => opening = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Lịch sử thanh toán'),
      actions: [
        IconButton(
          tooltip: 'Tải lại lịch sử',
          onPressed: loading ? null : () => load(pageOffset: offset),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: search,
            enabled: !loading,
            decoration: InputDecoration(
              hintText: 'Tìm mã hóa đơn hoặc bàn',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                tooltip: 'Tìm lịch sử',
                onPressed: loading ? null : () => load(),
                icon: const Icon(Icons.arrow_forward),
              ),
            ),
            onSubmitted: (_) => load(),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(error!, style: const TextStyle(color: Colors.red)),
                TextButton(
                  onPressed: () => load(pageOffset: offset),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
              ? const SizedBox.shrink()
              : receipts.isEmpty
              ? const Center(child: Text('Không có hóa đơn phù hợp.'))
              : RefreshIndicator(
                  onRefresh: () => load(pageOffset: offset),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: receipts.length,
                    itemBuilder: (_, index) {
                      final receipt = receipts[index];
                      return Card(
                        child: ListTile(
                          isThreeLine: true,
                          title: Text(
                            '${receipt['invoiceCode']} • Bàn ${receipt['tableCode']}',
                          ),
                          subtitle: Text(
                            '${invoiceDate(receipt['paidAt'])}\n${paymentMethods[receipt['paymentMethod']] ?? 'Không ghi nhận'} • ${invoiceMoney(receipt['totalAmount'] as num)}',
                          ),
                          trailing: opening == receipt['historyId']
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(),
                                )
                              : const Icon(Icons.receipt_long_outlined),
                          onTap: opening != null ? null : () => open(receipt),
                        ),
                      );
                    },
                  ),
                ),
        ),
        if (!loading && error == null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  tooltip: 'Trang trước',
                  onPressed: offset == 0
                      ? null
                      : () => load(pageOffset: offset - 30),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  total == 0
                      ? '0 hóa đơn'
                      : '${offset + 1}–${offset + receipts.length} / $total hóa đơn',
                ),
                IconButton(
                  tooltip: 'Trang sau',
                  onPressed: offset + receipts.length >= total
                      ? null
                      : () => load(pageOffset: offset + 30),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
