import 'package:flutter/material.dart';

import 'invoice_document.dart';
import 'staff_api.dart';

class InvoiceAddItemsDialog extends StatefulWidget {
  final StaffApi api;
  final Map<String, dynamic> invoice;
  const InvoiceAddItemsDialog({
    super.key,
    required this.api,
    required this.invoice,
  });
  @override
  State<InvoiceAddItemsDialog> createState() => _InvoiceAddItemsDialogState();
}

class _InvoiceAddItemsDialogState extends State<InvoiceAddItemsDialog> {
  final List<Map<String, dynamic>> lines = [];
  bool saving = false;
  String? error;

  Future<void> add() async {
    final item = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _MenuPicker(api: widget.api),
    );
    if (item == null || !mounted) return;
    setState(
      () => lines.add({
        'key': UniqueKey(),
        'menuItemId': item['id'],
        'name': item['name'],
        'unitPrice': item['price'],
        'quantity': 1,
        'note': '',
      }),
    );
  }

  Future<void> save() async {
    if (saving || lines.isEmpty) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final updated = await widget.api.saveInvoice(
        widget.invoice['tableId'] as int,
        widget.invoice['version'] as String,
        [
          ...(widget.invoice['items'] as List).map(
            (item) => <String, dynamic>{
              'itemId': item['id'],
              'quantity': item['quantity'],
            },
          ),
          ...lines.map(
            (line) => <String, dynamic>{
              'menuItemId': line['menuItemId'],
              'quantity': line['quantity'],
              'note': line['note'],
            },
          ),
        ],
        'Thêm món từ thu ngân',
      );
      if (mounted) Navigator.pop(context, updated);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AlertDialog(
      title: const Text('Thêm món'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
              if (lines.isEmpty)
                const Text(
                  'Chọn món cần thêm và ghi chú cách chế biến nếu có.',
                ),
              ...lines.map(
                (line) => Card(
                  key: line['key'] as Key,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          line['name'] as String,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(invoiceMoney(line['unitPrice'] as num)),
                        Row(
                          children: [
                            IconButton(
                              tooltip: 'Giảm ${line['name']}',
                              onPressed:
                                  saving || (line['quantity'] as int) <= 1
                                  ? null
                                  : () => setState(
                                      () => line['quantity'] =
                                          (line['quantity'] as int) - 1,
                                    ),
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            Text('${line['quantity']}'),
                            IconButton(
                              tooltip: 'Tăng ${line['name']}',
                              onPressed:
                                  saving || (line['quantity'] as int) >= 99
                                  ? null
                                  : () => setState(
                                      () => line['quantity'] =
                                          (line['quantity'] as int) + 1,
                                    ),
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Bỏ món mới ${line['name']}',
                              onPressed: saving
                                  ? null
                                  : () => setState(() => lines.remove(line)),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                        TextFormField(
                          initialValue: line['note'] as String,
                          enabled: !saving,
                          maxLength: 500,
                          decoration: const InputDecoration(
                            labelText: 'Ghi chú món mới',
                            hintText: 'Ví dụ: ít cay, không hành',
                          ),
                          onChanged: (value) => line['note'] = value,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: saving ? null : add,
                icon: const Icon(Icons.add),
                label: const Text('Chọn món'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: saving || lines.isEmpty ? null : save,
          child: Text(saving ? 'Đang thêm...' : 'Thêm vào hóa đơn'),
        ),
      ],
    ),
  );
}

class _MenuPicker extends StatefulWidget {
  final StaffApi api;
  const _MenuPicker({required this.api});
  @override
  State<_MenuPicker> createState() => _MenuPickerState();
}

class _MenuPickerState extends State<_MenuPicker> {
  List<Map<String, dynamic>>? menu;
  String query = '';
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => error = null);
    try {
      final items = await widget.api.cashierMenu();
      if (mounted) setState(() => menu = items);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Chọn món bổ sung'),
    content: SizedBox(
      width: 400,
      height: 360,
      child: Column(
        children: [
          TextField(
            decoration: const InputDecoration(
              hintText: 'Tìm món',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) =>
                setState(() => query = value.trim().toLowerCase()),
          ),
          if (error != null) ...[
            Text(error!),
            TextButton(onPressed: load, child: const Text('Thử lại')),
          ],
          if (menu == null && error == null) const CircularProgressIndicator(),
          if (menu != null)
            Expanded(
              child: Builder(
                builder: (_) {
                  final visible = menu!
                      .where(
                        (item) => (item['name'] as String)
                            .toLowerCase()
                            .contains(query),
                      )
                      .toList();
                  if (visible.isEmpty) {
                    return const Center(
                      child: Text('Không tìm thấy món đang phục vụ.'),
                    );
                  }
                  return ListView(
                    children: visible
                        .map(
                          (item) => ListTile(
                            title: Text(item['name'] as String),
                            subtitle: Text(invoiceMoney(item['price'] as num)),
                            trailing: const Icon(Icons.add_circle_outline),
                            onTap: () => Navigator.pop(context, item),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Đóng'),
      ),
    ],
  );
}
