import 'package:flutter/material.dart';

import 'staff_api.dart';
import 'restaurant_theme.dart';
import 'invoice_document.dart';

const promoWeekdays = {
  1: 'T2',
  2: 'T3',
  3: 'T4',
  4: 'T5',
  5: 'T6',
  6: 'T7',
  7: 'CN',
};
String promotionValue(Map<String, dynamic> p) =>
    p['discountType'] == 'percentage'
    ? '${p['discountValue']}%'
    : invoiceMoney(p['discountValue'] as num);
String promotionSchedule(Map<String, dynamic> p) => p['isAlwaysActive'] == true
    ? 'Liên tục 24/7 đến khi tắt'
    : '${p['allDay'] == true ? 'Nguyên ngày' : '${p['startTime']}–${p['endTime']}'} · ${(p['weekdays'] as List).map((d) => promoWeekdays[d]).join(', ')}\n${p['startDate']} → ${p['endDate']}';

class PromotionManagementPage extends StatefulWidget {
  final StaffApi api;
  const PromotionManagementPage({super.key, required this.api});
  @override
  State<PromotionManagementPage> createState() =>
      _PromotionManagementPageState();
}

class _PromotionManagementPageState extends State<PromotionManagementPage> {
  List<Map<String, dynamic>> promotions = [];
  bool loading = true, fetching = false;
  int? switching;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (fetching) return;
    setState(() => fetching = true);
    try {
      final data = await widget.api.managedPromotions();
      if (mounted) {
        setState(() {
          promotions = (data['promotions'] as List)
              .cast<Map<String, dynamic>>();
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
          fetching = false;
        });
      }
    }
  }

  Future<void> edit([Map<String, dynamic>? promotion]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          PromotionFormDialog(api: widget.api, promotion: promotion),
    );
    if (saved == true && mounted) await load();
  }

  Future<void> toggle(Map<String, dynamic> p, bool active) async {
    if (switching != null) return;
    setState(() => switching = p['id'] as int);
    try {
      await widget.api.togglePromotion(
        p['id'] as int,
        p['version'] as int,
        active,
      );
      if (mounted) await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => switching = null);
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: restaurantTheme(),
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Khuyến mãi'),
        actions: [
          IconButton(
            tooltip: 'Tải lại khuyến mãi',
            onPressed: fetching ? null : load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: loading || switching != null ? null : () => edit(),
        icon: const Icon(Icons.add),
        label: const Text('Thêm chương trình'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: RefreshIndicator(
                  onRefresh: load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const Text(
                        'Khuyến mãi toàn hóa đơn',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Khung giờ theo giờ Việt Nam (GMT+7). Không cộng dồn với voucher hoặc giảm thủ công.',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      if (fetching) const LinearProgressIndicator(),
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
                      if (promotions.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('Chưa có chương trình khuyến mãi.'),
                        ),
                      for (final p in promotions)
                        Card(
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        p['name'] as String,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Switch(
                                      key: ValueKey(
                                        'promotion-switch-${p['id']}',
                                      ),
                                      value: p['isActive'] as bool,
                                      onChanged: switching != null
                                          ? null
                                          : (value) => toggle(p, value),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${p['isActive'] == true ? 'Đang bật' : 'Tạm dừng'} · Giảm ${promotionValue(p)}',
                                  style: TextStyle(
                                    color: p['isActive'] == true
                                        ? const Color(0xFF23886B)
                                        : Colors.grey,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Giảm tối đa: ${p['maxDiscountAmount'] == null ? 'Không giới hạn' : invoiceMoney(p['maxDiscountAmount'] as num)}',
                                ),
                                Text(
                                  'Hóa đơn tối thiểu: ${invoiceMoney(p['minBillAmount'] as num)}',
                                ),
                                Text(promotionSchedule(p)),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: switching != null
                                        ? null
                                        : () => edit(p),
                                    icon: const Icon(Icons.edit_outlined),
                                    label: const Text('Sửa chương trình'),
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
            ),
    ),
  );
}

class PromotionFormDialog extends StatefulWidget {
  final StaffApi api;
  final Map<String, dynamic>? promotion;
  final bool discountCodeMode;
  const PromotionFormDialog({
    super.key,
    required this.api,
    this.promotion,
    this.discountCodeMode = false,
  });
  @override
  State<PromotionFormDialog> createState() => _PromotionFormState();
}

class _PromotionFormState extends State<PromotionFormDialog> {
  final quantity = TextEditingController(text: '100'),
      code = TextEditingController();
  String codeMode = 'auto';
  String get generatedCode {
    final words = searchText(name.text)
        .toUpperCase()
        .split(RegExp('[^A-Z0-9]+'))
        .where((w) => w.isNotEmpty);
    final amount = number(value.text) ?? 0;
    final amountText =
        (amount.isFinite && amount == amount.roundToDouble()
                ? amount.toInt().toString()
                : amount.toString())
            .replaceAll('.', '');
    final suffix = '${int.tryParse(quantity.text) ?? 0}$amountText';
    final prefix = words.map((w) => w[0]).join();
    final available = (64 - suffix.length).clamp(0, 64);
    return '${prefix.substring(0, prefix.length < available ? prefix.length : available)}$suffix';
  }

  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      value = TextEditingController(),
      cap = TextEditingController(),
      minimum = TextEditingController();
  String type = 'percentage';
  bool isActive = true, always = false, allDay = true, busy = false;
  Set<int> weekdays = {1, 2, 3, 4, 5, 6, 7};
  TimeOfDay start = const TimeOfDay(hour: 14, minute: 0),
      end = const TimeOfDay(hour: 17, minute: 0);
  late DateTime from, to;
  String? error;
  String day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String clock(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  num? number(String text) => num.tryParse(text.trim().replaceAll(',', '.'));
  @override
  void initState() {
    super.initState();
    final now = DateTime.now().toUtc().add(const Duration(hours: 7));
    from = DateTime(now.year, now.month, now.day);
    to = from.add(const Duration(days: 30));
    final p = widget.promotion;
    if (p != null) {
      if (widget.discountCodeMode) {
        quantity.text = '${p['totalQuantity']}';
        code.text = p['discountCode'] as String;
        codeMode = p['codeMode'] as String;
      }
      name.text = p['name'] as String;
      type = p['discountType'] as String;
      value.text = '${p['discountValue']}';
      cap.text = p['maxDiscountAmount']?.toString() ?? '';
      minimum.text = '${p['minBillAmount']}';
      isActive = p['isActive'] as bool;
      always = p['isAlwaysActive'] as bool;
      allDay = p['allDay'] as bool;
      weekdays = (p['weekdays'] as List).cast<int>().toSet();
      if (p['startDate'] != null) {
        from = DateTime.parse(p['startDate'] as String);
      }
      if (p['endDate'] != null) to = DateTime.parse(p['endDate'] as String);
      TimeOfDay parse(String s) => TimeOfDay(
        hour: int.parse(s.substring(0, 2)),
        minute: int.parse(s.substring(3)),
      );
      if (p['startTime'] != null) start = parse(p['startTime'] as String);
      if (p['endTime'] != null) end = parse(p['endTime'] as String);
    }
  }

  @override
  void dispose() {
    quantity.dispose();
    code.dispose();
    name.dispose();
    value.dispose();
    cap.dispose();
    minimum.dispose();
    super.dispose();
  }

  Future<void> dates() async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2099, 12, 31),
      initialDateRange: DateTimeRange(start: from, end: to),
      helpText: widget.discountCodeMode
          ? 'Chọn khoảng ngày giảm giá'
          : 'Chọn khoảng ngày khuyến mãi',
      saveText: 'Áp dụng',
      confirmText: 'Áp dụng',
      cancelText: 'Hủy',
    );
    if (result != null && mounted) {
      setState(() {
        from = result.start;
        to = result.end;
        always = false;
      });
    }
  }

  Future<void> chooseTime(bool first) async {
    final result = await showTimePicker(
      context: context,
      initialTime: first ? start : end,
      initialEntryMode: TimePickerEntryMode.input,
      helpText: first ? 'Chọn giờ bắt đầu' : 'Chọn giờ kết thúc',
      confirmText: 'Chọn',
      cancelText: 'Hủy',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        always = false;
        allDay = false;
        if (first) {
          start = result;
        } else {
          end = result;
        }
      });
    }
  }

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    if (!always && (weekdays.isEmpty || (!allDay && start == end))) {
      setState(
        () => error = 'Chọn ít nhất một thứ và giờ bắt đầu/kết thúc khác nhau.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final payload = <String, dynamic>{
        'name': name.text.trim(),
        'discountType': type,
        'discountValue': number(value.text),
        'maxDiscountAmount': cap.text.trim().isEmpty ? null : number(cap.text),
        'minBillAmount': minimum.text.trim().isEmpty ? 0 : number(minimum.text),
        'isActive': isActive,
        'isAlwaysActive': always,
        'allDay': allDay,
        'startTime': allDay ? null : clock(start),
        'endTime': allDay ? null : clock(end),
        'weekdays': weekdays.toList()..sort(),
        'startDate': always ? null : day(from),
        'endDate': always ? null : day(to),
        if (widget.promotion != null) 'version': widget.promotion!['version'],
      };
      if (widget.discountCodeMode) {
        payload.remove('name');
        payload.remove('discountValue');
        payload.remove('minBillAmount');
        payload.addAll({
          'discountName': name.text.trim(),
          'totalQuantity': int.parse(quantity.text),
          'codeMode': codeMode,
          if (codeMode == 'manual')
            'discountCode': code.text.trim().toUpperCase(),
          'discountPercent': type == 'percentage' ? number(value.text) : null,
          'fixedAmount': type == 'fixed' ? number(value.text) : null,
          'minOrderValue': minimum.text.trim().isEmpty
              ? 0
              : number(minimum.text),
        });
        await widget.api.saveDiscountCode(
          payload,
          id: widget.promotion?['id'] as int?,
        );
      } else {
        await widget.api.savePromotion(
          payload,
          id: widget.promotion?['id'] as int?,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String? moneyValidator(
    String? text, {
    bool optional = false,
    bool zero = false,
  }) {
    if (optional && (text?.trim().isEmpty ?? true)) return null;
    final n = number(text ?? '');
    return n == null ||
            !n.isFinite ||
            n < (zero ? 0 : 1) ||
            n > 999999999 ||
            n != n.roundToDouble()
        ? 'Nhập số tiền nguyên hợp lệ.'
        : null;
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: Text(
        widget.discountCodeMode
            ? (widget.promotion == null ? 'Tạo mã giảm giá' : 'Sửa mã giảm giá')
            : (widget.promotion == null ? 'Thêm khuyến mãi' : 'Sửa khuyến mãi'),
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const Key('promo-name'),
                  controller: name,
                  onChanged: (_) => setState(() {}),
                  enabled: !busy,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Tên chương trình',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Nhập tên chương trình.'
                      : null,
                ),
                if (widget.discountCodeMode) ...[
                  TextFormField(
                    controller: quantity,
                    enabled: !busy,
                    key: const Key('discount-quantity'),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Số lượng phát hành',
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      return n == null || n < 1 || n > 1000000000
                          ? 'Nhập số lượng từ 1 đến 1 tỷ.'
                          : null;
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: const Key('discount-code'),
                          controller: code,
                          enabled: !busy,
                          maxLength: 64,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Mã voucher',
                          ),
                          onChanged: (_) => codeMode = 'manual',
                          validator: (v) =>
                              RegExp(r'^[A-Z0-9_-]{1,64}$')
                                  .hasMatch((v ?? '').trim().toUpperCase())
                              ? null
                              : 'Nhập mã hoặc bấm Gợi ý.',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: OutlinedButton.icon(
                          key: const Key('discount-suggest-code'),
                          onPressed: busy
                              ? null
                              : () => setState(() {
                                  code.text = generatedCode;
                                  codeMode = 'auto';
                                }),
                          icon: const Icon(Icons.auto_awesome_outlined),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                          label: const Text('Gợi ý'),
                        ),
                      ),
                    ],
                  ),
                ],
                const Text(
                  'Áp dụng: Toàn hóa đơn',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  key: const Key('promo-type'),
                  initialValue: type,
                  decoration: const InputDecoration(
                    labelText: 'Hình thức giảm',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'percentage',
                      child: Text('Phần trăm (%)'),
                    ),
                    DropdownMenuItem(
                      value: 'fixed',
                      child: Text('Số tiền cố định'),
                    ),
                  ],
                  onChanged: busy ? null : (v) => setState(() => type = v!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('promo-value'),
                  controller: value,
                  onChanged: (_) => setState(() {}),
                  enabled: !busy,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Giá trị giảm',
                    suffixText: type == 'percentage' ? '%' : 'đ',
                  ),
                  validator: (v) {
                    final n = number(v ?? '');
                    if (n == null ||
                        !n.isFinite ||
                        n <= 0 ||
                        (type == 'percentage' &&
                            (n > 100 ||
                                ((n * 100) - (n * 100).round()).abs() >
                                    0.000001))) {
                      return 'Nhập mức giảm hợp lệ (tối đa 100%).';
                    }
                    return type == 'fixed' ? moneyValidator(v) : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('promo-cap'),
                  controller: cap,
                  enabled: !busy,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Giảm tối đa (đ)',
                    helperText: 'Để trống nếu không giới hạn',
                  ),
                  validator: (v) => moneyValidator(v, optional: true),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('promo-minimum'),
                  controller: minimum,
                  enabled: !busy,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Hóa đơn tối thiểu (đ)',
                  ),
                  validator: (v) =>
                      moneyValidator(v, optional: true, zero: true),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Bật chương trình'),
                  value: isActive,
                  onChanged: busy ? null : (v) => setState(() => isActive = v),
                ),
                SwitchListTile(
                  key: const Key('promo-always'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Áp dụng liên tục 24/7'),
                  subtitle: const Text('Đến khi quản lý tắt thủ công'),
                  value: always,
                  onChanged: busy ? null : (v) => setState(() => always = v),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Chọn ngày và giờ áp dụng',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  always
                      ? 'Đang áp dụng 24/7. Chọn ngày hoặc giờ bên dưới để chuyển sang lịch cố định.'
                      : 'Chương trình chỉ áp dụng theo ngày, thứ và khung giờ đã chọn.',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                OutlinedButton.icon(
                  key: const Key('promo-dates'),
                  onPressed: busy ? null : dates,
                  icon: const Icon(Icons.date_range),
                  label: const Text('Chọn khoảng ngày'),
                ),
                Text('Từ ngày: ${day(from)}\nĐến ngày: ${day(to)}'),
                SwitchListTile(
                  key: const Key('promo-all-day'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Áp dụng nguyên ngày'),
                  value: allDay,
                  onChanged: busy
                      ? null
                      : (v) => setState(() {
                          allDay = v;
                          always = false;
                        }),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      key: const Key('promo-start'),
                      onPressed: busy ? null : () => chooseTime(true),
                      child: Text('Giờ bắt đầu: ${clock(start)}'),
                    ),
                    OutlinedButton(
                      key: const Key('promo-end'),
                      onPressed: busy ? null : () => chooseTime(false),
                      child: Text('Giờ kết thúc: ${clock(end)}'),
                    ),
                  ],
                ),
                const Text(
                  'Chọn giờ để dùng khung giờ cố định. Giờ Việt Nam; giờ kết thúc nhỏ hơn giờ bắt đầu là khung qua đêm.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 8),
                const Text('Ngày trong tuần'),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final e in promoWeekdays.entries)
                      FilterChip(
                        label: Text(e.value),
                        selected: weekdays.contains(e.key),
                        onSelected: busy
                            ? null
                            : (v) => setState(() {
                                always = false;
                                if (v) {
                                  weekdays.add(e.key);
                                } else {
                                  weekdays.remove(e.key);
                                }
                              }),
                      ),
                  ],
                ),
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: busy ? null : submit,
          child: Text(
            busy
                ? 'Đang lưu...'
                : widget.discountCodeMode
                ? 'Lưu mã giảm giá'
                : 'Lưu chương trình',
          ),
        ),
      ],
    ),
  );
}
