import 'package:flutter/material.dart';

import 'invoice_document.dart';
import 'invoice_editor.dart';
import 'staff_api.dart';

class InvoiceDialog extends StatefulWidget {
  final StaffApi api;
  final int tableId;
  final Map<String, dynamic>? receipt;
  final void Function(Map<String, dynamic>) onPaid;
  final VoidCallback? onUpdated;
  const InvoiceDialog({
    super.key,
    required this.api,
    required this.tableId,
    required this.onPaid,
    this.receipt,
    this.onUpdated,
  });

  @override
  State<InvoiceDialog> createState() => _InvoiceDialogState();
}

class _InvoiceDialogState extends State<InvoiceDialog> {
  Map<String, dynamic>? invoice;
  String method = 'cash';
  String? error;
  bool busy = false;
  final percentage = TextEditingController();
  final voucher = TextEditingController();
  String discountMode = 'manual';
  bool discountDirty = false;
  bool discountExpanded = false;
  String? discountInputError;

  @override
  void initState() {
    super.initState();
    invoice = widget.receipt;
    if (invoice != null) syncDiscount(invoice!);
    if (invoice == null) load();
  }

  Future<void> load() async {
    setState(() => error = null);
    try {
      final data = await widget.api.invoice(widget.tableId);
      if (mounted) {
        setState(() {
          invoice = data;
          syncDiscount(data);
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  @override
  void dispose() {
    percentage.dispose();
    voucher.dispose();
    super.dispose();
  }

  void syncDiscount(Map<String, dynamic> bill) {
    discountMode = bill['discountMode'] == 'voucher' ? 'voucher' : 'manual';
    final value = (bill['discountPercentage'] as num?) ?? 0;
    percentage.text = value == 0 ? '' : value.toString();
    voucher.text = bill['voucherCode'] as String? ?? '';
    discountDirty = false;
    discountInputError = null;
  }

  Future<void> applyDiscount({bool clear = false}) async {
    if (busy) return;
    final value = num.tryParse(percentage.text.trim().replaceAll(',', '.'));
    if (!clear &&
        discountMode == 'manual' &&
        (value == null ||
            !value.isFinite ||
            value < 0 ||
            value > 100 ||
            ((value * 100) - (value * 100).round()).abs() > 0.000001)) {
      setState(
        () => discountInputError =
            'Nhập mức giảm từ 0 đến 100%, tối đa 2 chữ số thập phân.',
      );
      return;
    }
    if (!clear && discountMode == 'voucher' && voucher.text.trim().isEmpty) {
      setState(() => discountInputError = 'Vui lòng nhập mã voucher.');
      return;
    }
    setState(() {
      busy = true;
      discountInputError = null;
    });
    try {
      final updated = await widget.api.applyDiscount(
        widget.tableId,
        invoice!['version'] as String,
        clear ? 'none' : discountMode,
        percentage: value,
        code: voucher.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        invoice = updated;
        syncDiscount(updated);
      });
      widget.onUpdated?.call();
    } catch (e) {
      if (mounted) setState(() => discountInputError = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> pay() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.api.pay(
        widget.tableId,
        method,
        orderCodes: invoice!['orderCodes'] as List<dynamic>,
        version: invoice!['version'] as String?,
      );
      final receipt = result['invoice'] as Map<String, dynamic>;
      widget.onPaid(receipt);
      if (mounted) setState(() => invoice = receipt);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> printReceipt() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await printInvoice(invoice!);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Không mở được chức năng in. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> edit() async {
    final updated = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => InvoiceAddItemsDialog(api: widget.api, invoice: invoice!),
    );
    if (updated == null || !mounted) return;
    setState(() {
      invoice = updated;
      error = null;
    });
    widget.onUpdated?.call();
  }

  Future<void> changeItem(
    Map<String, dynamic> item, {
    int? quantity,
    bool remove = false,
  }) async {
    if (busy || invoice?['paymentStatus'] == 'paid') return;
    final lines = (invoice!['items'] as List)
        .where((line) => !remove || line['id'] != item['id'])
        .map(
          (line) => <String, dynamic>{
            'itemId': line['id'],
            'quantity': line['id'] == item['id'] && quantity != null
                ? quantity
                : line['quantity'],
          },
        )
        .toList();
    if (lines.isEmpty) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final updated = await widget.api.saveInvoice(
        widget.tableId,
        invoice!['version'] as String,
        lines,
        '${remove ? 'Xóa món' : 'Đổi số lượng'}: ${item['name']}',
      );
      if (!mounted) return;
      setState(() => invoice = updated);
      widget.onUpdated?.call();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget discountSection(Map<String, dynamic> bill, bool paid) {
    final savedMode = bill['discountMode'] as String? ?? 'none';
    final amount = (bill['discountAmount'] as num?) ?? 0;
    final percent = (bill['discountPercentage'] as num?) ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        if (!paid)
          OutlinedButton.icon(
            key: const Key('toggle-discount'),
            onPressed: busy
                ? null
                : () => setState(() => discountExpanded = !discountExpanded),
            icon: Icon(
              discountExpanded
                  ? Icons.keyboard_arrow_up_outlined
                  : Icons.local_offer_outlined,
            ),
            label: Text(
              discountExpanded
                  ? 'Thu gọn giảm giá'
                  : savedMode == 'none'
                  ? 'Giảm giá'
                  : 'Giảm giá đã áp dụng',
            ),
          ),
        if (paid || discountExpanded) ...[
          if (!paid) const SizedBox(height: 8),
          const Text('Giảm giá', style: TextStyle(fontWeight: FontWeight.bold)),
          if (!paid) ...[
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'manual', label: Text('Nhập %')),
                ButtonSegment(value: 'voucher', label: Text('Mã voucher')),
              ],
              selected: {discountMode},
              onSelectionChanged: busy
                  ? null
                  : (value) => setState(() {
                      discountMode = value.first;
                      discountDirty = true;
                      discountInputError = null;
                    }),
            ),
            const SizedBox(height: 12),
            if (discountMode == 'manual')
              TextField(
                key: const Key('manual-discount'),
                controller: percentage,
                enabled: !busy,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Phần trăm giảm giá',
                  hintText: 'Ví dụ: 10',
                  suffixText: '%',
                ),
                onChanged: (_) => setState(() => discountDirty = true),
              )
            else
              TextField(
                key: const Key('voucher-code'),
                controller: voucher,
                enabled: !busy,
                maxLength: 40,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Nhập mã voucher'),
                onChanged: (_) => setState(() => discountDirty = true),
              ),
            if (discountInputError != null)
              Text(
                discountInputError!,
                style: const TextStyle(color: Colors.red),
              ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : () => applyDiscount(),
                    child: const Text('Áp dụng'),
                  ),
                ),
                if (savedMode != 'none' || discountDirty)
                  TextButton(
                    onPressed: busy
                        ? null
                        : () {
                            if (savedMode != 'none') {
                              applyDiscount(clear: true);
                            } else {
                              setState(() => syncDiscount(bill));
                            }
                          },
                    child: const Text('Bỏ giảm giá'),
                  ),
              ],
            ),
            if (discountDirty)
              const Text(
                'Bấm Áp dụng để lưu mức giảm.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
          if (bill['discountError'] != null)
            Text(
              bill['discountError'] as String,
              style: const TextStyle(color: Colors.red),
            ),
          const SizedBox(height: 8),
          Text(
            'Tiền món: ${invoiceMoney((bill['subtotalAmount'] as num?) ?? bill['totalAmount'] as num)}',
          ),
          Text(
            'Giảm giá${savedMode == 'voucher'
                ? ' (${bill['voucherCode']})'
                : percent > 0
                ? ' ($percent%)'
                : ''}: −${invoiceMoney(amount)}',
          ),
          Text(
            'Cần thanh toán: ${invoiceMoney(bill['totalAmount'] as num)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bill = invoice;
    final paid = bill?['paymentStatus'] == 'paid';
    final pending = (bill?['pendingItems'] as num?)?.toInt() ?? 0;
    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        title: const Text('Chi tiết hóa đơn'),
        content: SizedBox(
          width: 340,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (error != null) ...[
                  Text(error!, style: const TextStyle(color: Colors.red)),
                  if (bill == null)
                    TextButton(onPressed: load, child: const Text('Thử lại')),
                ],
                if (bill == null && error == null)
                  const Center(child: CircularProgressIndicator()),
                if (bill != null) ...[
                  Text(
                    'SmartRes • ${bill['invoiceCode']}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text('PHIẾU THANH TOÁN', textAlign: TextAlign.center),
                  const Text(
                    'Bill in nhiệt • 80 mm',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Bàn ${bill['tableCode']} • ${bill['guests'] ?? '—'} khách',
                  ),
                  Text('Ngày giờ: ${invoiceDate(bill['issuedAt'])} (GMT+7)'),
                  Text(
                    paid ? 'Đã thanh toán' : 'Chưa thanh toán',
                    style: TextStyle(
                      color: paid ? Colors.green : Colors.orange,
                    ),
                  ),
                  const Divider(height: 24),
                  if (!paid)
                    OutlinedButton.icon(
                      onPressed: busy ? null : edit,
                      icon: const Icon(Icons.add),
                      label: const Text('Thêm món'),
                    ),
                  const Row(
                    children: [
                      Expanded(child: Text('Món / SL x Đơn giá')),
                      Text('Thành tiền'),
                    ],
                  ),
                  ...(bill['items'] as List).map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(item['name'] as String)),
                              if (!paid) ...[
                                IconButton(
                                  tooltip: 'Giảm ${item['name']}',
                                  constraints: const BoxConstraints.tightFor(
                                    width: 32,
                                    height: 40,
                                  ),
                                  padding: EdgeInsets.zero,
                                  onPressed:
                                      busy || (item['quantity'] as num) <= 1
                                      ? null
                                      : () => changeItem(
                                          item as Map<String, dynamic>,
                                          quantity:
                                              (item['quantity'] as num)
                                                  .toInt() -
                                              1,
                                        ),
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    size: 20,
                                  ),
                                ),
                                SizedBox(
                                  width: 22,
                                  child: Text(
                                    '${item['quantity']}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Tăng ${item['name']}',
                                  constraints: const BoxConstraints.tightFor(
                                    width: 32,
                                    height: 40,
                                  ),
                                  padding: EdgeInsets.zero,
                                  onPressed:
                                      busy || (item['quantity'] as num) >= 99
                                      ? null
                                      : () => changeItem(
                                          item as Map<String, dynamic>,
                                          quantity:
                                              (item['quantity'] as num)
                                                  .toInt() +
                                              1,
                                        ),
                                  icon: const Icon(
                                    Icons.add_circle_outline,
                                    size: 20,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Xóa ${item['name']}',
                                  constraints: const BoxConstraints.tightFor(
                                    width: 32,
                                    height: 40,
                                  ),
                                  padding: EdgeInsets.zero,
                                  onPressed:
                                      busy ||
                                          (bill['items'] as List).length <= 1
                                      ? null
                                      : () => changeItem(
                                          item as Map<String, dynamic>,
                                          remove: true,
                                        ),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 20,
                                  ),
                                  color: Colors.red,
                                ),
                              ],
                            ],
                          ),
                          if ((item['note'] as String? ?? '').isNotEmpty)
                            Text(
                              'Ghi chú: ${item['note']}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${item['quantity']} x ${invoiceMoney(item['unitPrice'] as num)}',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(invoiceMoney(item['lineTotal'] as num)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(),
                  Text(
                    'Tổng tiền: ${invoiceMoney(bill['totalAmount'] as num)}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (paid)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Phương thức thanh toán: ${paymentMethods[bill['paymentMethod']] ?? 'Không ghi nhận'}',
                        ),
                        if (bill['cashierName'] != null)
                          Text('Thu ngân: ${bill['cashierName']}'),
                      ],
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: method,
                      decoration: const InputDecoration(
                        labelText: 'Phương thức thanh toán',
                      ),
                      items: paymentMethods.entries
                          .map(
                            (entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(),
                      onChanged: busy
                          ? null
                          : (value) => setState(() => method = value!),
                    ),
                  discountSection(bill, paid),
                  if (!paid && pending > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'Còn $pending món chưa phục vụ. Chưa thể xác nhận thanh toán.',
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
          if (bill != null && !paid)
            FilledButton.icon(
              onPressed:
                  busy ||
                      pending > 0 ||
                      discountDirty ||
                      bill['discountError'] != null
                  ? null
                  : pay,
              icon: const Icon(Icons.payments_outlined),
              label: Text(busy ? 'Đang xử lý...' : 'Xác nhận thanh toán'),
            ),
          if (paid)
            FilledButton.icon(
              onPressed: busy ? null : printReceipt,
              icon: const Icon(Icons.print_outlined),
              label: Text(busy ? 'Đang mở...' : 'In hóa đơn'),
            ),
        ],
      ),
    );
  }
}
