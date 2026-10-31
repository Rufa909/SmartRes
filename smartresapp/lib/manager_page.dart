import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'staff_api.dart';
import 'menu_management_page.dart';
import 'staff_page.dart';
import 'kitchen_page.dart';
import 'cashier_page.dart';
import 'cashier_history_page.dart';
import 'invoice_dialog.dart';
import 'restaurant_theme.dart';

String _money(num value) =>
    '${value.round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')} đ';
String _day(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
String _short(String value) => value.length >= 10
    ? '${value.substring(8, 10)}/${value.substring(5, 7)}'
    : value;
String _compact(num value) => value >= 1000000
    ? '${(value / 1000000).toStringAsFixed(1)}tr'
    : value >= 1000
    ? '${(value / 1000).toStringAsFixed(0)}k'
    : '${value.round()}';
DateTime _today() {
  final now = DateTime.now().toUtc().add(const Duration(hours: 7));
  return DateTime(now.year, now.month, now.day);
}

String _time(String value) {
  final time = DateTime.parse(value).toUtc().add(const Duration(hours: 7));
  return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

class ManagerPage extends StatefulWidget {
  final StaffApi api;
  final bool autoRefresh;
  const ManagerPage({super.key, required this.api, this.autoRefresh = true});
  @override
  State<ManagerPage> createState() => _ManagerPageState();
}

class _ManagerPageState extends State<ManagerPage> {
  Map<String, dynamic>? data;
  String? error;
  late DateTime from, to;
  String preset = '7 ngày';
  bool refreshing = false;
  int generation = 0;
  int? openingReceipt;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    to = _today();
    from = to.subtract(const Duration(days: 6));
    load();
    if (widget.autoRefresh) {
      timer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (!refreshing && (ModalRoute.of(context)?.isCurrent ?? true)) load();
      });
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    final request = ++generation;
    setState(() => refreshing = true);
    try {
      final next = await widget.api.managementOverview(_day(from), _day(to));
      if (next['summary'] is! Map || next['operations'] is! Map) {
        throw StaffApiError('Chưa tải được tổng quan. Vui lòng thử lại.');
      }
      if (!mounted || request != generation) return;
      setState(() {
        data = next;
        error = null;
      });
    } catch (e) {
      if (mounted && request == generation) {
        setState(() => error = e.toString());
      }
    } finally {
      if (mounted && request == generation) setState(() => refreshing = false);
    }
  }

  void select(String value) {
    final today = _today();
    setState(() {
      preset = value;
      to = today;
      from = value == 'Hôm nay'
          ? today
          : value == 'Tháng này'
          ? DateTime(today.year, today.month, 1)
          : today.subtract(const Duration(days: 6));
      data = null;
      error = null;
    });
    load();
  }

  Future<void> chooseRange() async {
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2099, 12, 31),
      initialDateRange: DateTimeRange(start: from, end: to),
      helpText: 'CHỌN KHOẢNG NGÀY',
      saveText: 'Áp dụng',
    );
    if (selected == null || !mounted) return;
    if (selected.end.difference(selected.start).inDays >= 366) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Chọn tối đa 366 ngày.')));
      return;
    }
    setState(() {
      from = selected.start;
      to = selected.end;
      preset = 'Tùy chọn';
      data = null;
      error = null;
    });
    await load();
  }

  Future<void> open(Widget page) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
    if (mounted) await load();
  }

  Future<void> openReceipt(Map<String, dynamic> receipt) async {
    if (openingReceipt != null) return;
    setState(() => openingReceipt = receipt['historyId'] as int);
    try {
      final invoice = await widget.api.savedInvoice(
        receipt['historyId'] as int,
      );
      if (!mounted) return;
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
      if (mounted) setState(() => openingReceipt = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = data?['summary'] as Map<String, dynamic>?;
    final operations = data?['operations'] as Map<String, dynamic>?;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SMARTRES · QUẢN LÝ',
              style: TextStyle(
                fontSize: 10,
                color: brandOrange,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Tổng quan nhà hàng',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Cập nhật tổng quan',
            onPressed: refreshing ? null : load,
            icon: const Icon(Icons.refresh),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFFFFEEE9),
              child: Text(
                'QL',
                style: TextStyle(
                  color: brandOrange,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          if (index == 1) open(MenuManagementPage(api: widget.api));
          if (index == 2) open(StaffPage(api: widget.api));
          if (index == 3) open(CashierHistoryPage(api: widget.api));
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Tổng quan',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu),
            label: 'Thực đơn',
          ),
          NavigationDestination(
            icon: Icon(Icons.table_restaurant_outlined),
            label: 'Vận hành',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Hóa đơn',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final value in ['Hôm nay', '7 ngày', 'Tháng này'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(value),
                        selected: preset == value,
                        onSelected: (_) => select(value),
                      ),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.date_range, size: 17),
                    label: Text(
                      preset == 'Tùy chọn' ? 'Đổi khoảng ngày' : 'Tùy chọn',
                    ),
                    onPressed: chooseRange,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${_short(_day(from))}/${from.year} – ${_short(_day(to))}/${to.year} · Giờ Việt Nam',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 14),
            if (refreshing) const LinearProgressIndicator(minHeight: 2),
            if (error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEEE9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(error!, style: const TextStyle(color: Colors.red)),
                    if (data != null)
                      const Text('Dữ liệu hiển thị có thể đã cũ.'),
                    TextButton(
                      onPressed: refreshing ? null : load,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            if (data == null && error == null)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: Text('Đang tải số liệu từ MySQL...')),
              ),
            if (summary != null) ...[
              revenueCard(summary),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: metric(
                      'Hóa đơn',
                      '${summary['invoiceCount']}',
                      Icons.receipt_long,
                      const Color(0xFF3366CC),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: metric(
                      'TB / hóa đơn',
                      _money(summary['averageBill'] as num),
                      Icons.payments_outlined,
                      const Color(0xFF23886B),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: metric(
                      'Đã giảm giá',
                      _money(summary['discountAmount'] as num),
                      Icons.local_offer_outlined,
                      brandOrange,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            const Text(
              'Truy cập nhanh',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: shortcut(
                    'Quản lý thực đơn',
                    Icons.restaurant_menu,
                    brandOrange,
                    () => open(MenuManagementPage(api: widget.api)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: shortcut(
                    'Vận hành bàn',
                    Icons.table_restaurant,
                    const Color(0xFF3366CC),
                    () => open(StaffPage(api: widget.api)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: shortcut(
                    'Bếp',
                    Icons.soup_kitchen_outlined,
                    const Color(0xFF8853B7),
                    () => open(KitchenPage(api: widget.api)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: shortcut(
                    'Thu ngân',
                    Icons.point_of_sale,
                    const Color(0xFF23886B),
                    () => open(CashierPage(api: widget.api)),
                  ),
                ),
              ],
            ),
            if (operations != null) ...[
              const SizedBox(height: 18),
              operationCard(operations),
              const SizedBox(height: 18),
              section(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Biểu đồ doanh thu',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(
                      'Theo ngày · Sau giảm giá',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    RevenueBars(
                      daily: (data!['daily'] as List)
                          .cast<Map<String, dynamic>>(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              topItems(
                (data!['topItems'] as List).cast<Map<String, dynamic>>(),
              ),
              const SizedBox(height: 18),
              paymentMethods(
                (data!['paymentMethods'] as List).cast<Map<String, dynamic>>(),
              ),
              const SizedBox(height: 18),
              recent(
                (data!['recentInvoices'] as List).cast<Map<String, dynamic>>(),
              ),
              const SizedBox(height: 12),
              Text(
                'Cập nhật ${_time(data!['generatedAt'] as String)} · Tự làm mới mỗi 30 giây',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget section({required Widget child}) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: const BorderSide(color: Color(0xFFE9EBEF)),
    ),
    child: Padding(padding: const EdgeInsets.all(18), child: child),
  );
  Widget revenueCard(Map<String, dynamic> s) {
    final change = s['changePercent'] as num?;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF212B3B), Color(0xFF35435B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                color: Color(0xFFFFAD99),
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'DOANH THU ĐÃ THU',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _money(s['revenue'] as num),
              key: const Key('manager-revenue'),
              style: const TextStyle(
                fontSize: 35,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            change == null
                ? 'Chưa có doanh thu kỳ trước để so sánh.'
                : '${change >= 0 ? '↑' : '↓'} ${change.abs().toStringAsFixed(1)}% so với kỳ trước',
            style: TextStyle(
              color: change == null
                  ? Colors.white60
                  : change >= 0
                  ? const Color(0xFF99E7BE)
                  : const Color(0xFFFFB9AC),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Kỳ trước: ${_money(s['previousRevenue'] as num)}',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 10),
          const Text(
            'Tính từ hóa đơn đã thanh toán, sau giảm giá.',
            style: TextStyle(color: Colors.white60, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget metric(String label, String value, IconData icon, Color color) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 21),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.black54),
            ),
          ],
        ),
      );
  Widget shortcut(String title, IconData icon, Color color, VoidCallback tap) =>
      Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: tap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  Widget operationCard(Map<String, dynamic> o) {
    final used =
            (o['diningTables'] as num) + (o['waitingPaymentTables'] as num),
        total = o['totalTables'] as num;
    return section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.circle, color: Color(0xFF23886B), size: 8),
              SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Vận hành hiện tại',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${used.toInt()}/${total.toInt()} bàn đang dùng · ${o['availableTables']} bàn trống',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: total > 0 ? (used / total).clamp(0, 1).toDouble() : 0,
            minHeight: 7,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              Text('${o['guests']} khách'),
              Text('${o['pendingKitchen']} phần chờ bếp'),
              Text('${o['readyToServe']} phần chờ phục vụ'),
            ],
          ),
          const Divider(height: 24),
          Text(
            '${o['waitingPaymentTables']} bàn chờ thanh toán',
            style: const TextStyle(
              color: brandOrange,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tiền món chưa thu: ${_money(o['unpaidAmount'] as num)}',
            style: const TextStyle(fontSize: 12),
          ),
          const Text(
            'Chưa trừ giảm giá · Không cộng vào doanh thu đã thu',
            style: TextStyle(fontSize: 10, color: Colors.black54),
          ),
          if ((o['outOfStock'] as num) > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                '${o['outOfStock']} món đang hết bán',
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget topItems(List<Map<String, dynamic>> items) => section(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Món bán chạy',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const Text(
          'Theo số phần · Giá trị món trước giảm giá',
          style: TextStyle(fontSize: 11, color: Colors.black54),
        ),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text('Chưa có món bán trong khoảng ngày này.'),
          ),
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: const Color(0xFFFFEEE9),
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      color: brandOrange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        items[i]['name'] as String,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${items[i]['quantity']} phần',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _money(items[i]['grossAmount'] as num),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
  Widget paymentMethods(List<Map<String, dynamic>> methods) => section(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Phương thức thanh toán',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        if (methods.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Chưa có hóa đơn đã thanh toán.'),
          ),
        for (final method in methods)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${switch (method['method']) {
                      'cash' => 'Tiền mặt',
                      'bank_transfer' => 'Chuyển khoản',
                      'card' => 'Thẻ',
                      _ => 'Khác',
                    }} · ${method['invoiceCount']} bill',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Text(
                  _money(method['revenue'] as num),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
  Widget recent(List<Map<String, dynamic>> receipts) => section(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Hóa đơn gần đây',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            TextButton(
              onPressed: () => open(CashierHistoryPage(api: widget.api)),
              child: const Text('Xem tất cả'),
            ),
          ],
        ),
        if (receipts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Không có hóa đơn trong khoảng đã chọn.'),
          ),
        for (final receipt in receipts)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            onTap: openingReceipt == null ? () => openReceipt(receipt) : null,
            title: Text(
              receipt['invoiceCode'] as String,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            subtitle: Text(
              '${receipt['tableCode']} · ${_short((DateTime.parse(receipt['paidAt'] as String).toUtc().add(const Duration(hours: 7))).toIso8601String())} ${_time(receipt['paidAt'] as String)}',
            ),
            trailing: openingReceipt == receipt['historyId']
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    _money(receipt['totalAmount'] as num),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
          ),
      ],
    ),
  );
}

class RevenueBars extends StatelessWidget {
  final List<Map<String, dynamic>> daily;
  const RevenueBars({super.key, required this.daily});
  @override
  Widget build(BuildContext context) {
    final maxRevenue = daily.fold<num>(
      0,
      (max, d) => math.max(max, d['revenue'] as num),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (maxRevenue == 0)
          const Text(
            'Chưa có doanh thu trong khoảng ngày này.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        LayoutBuilder(
          builder: (context, size) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: math.max(size.maxWidth, daily.length * 48.0),
              height: 180,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final day in daily)
                    Expanded(
                      child: Tooltip(
                        message:
                            '${day['date']}: ${_money(day['revenue'] as num)}',
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                (day['revenue'] as num) > 0
                                    ? _compact(day['revenue'] as num)
                                    : '0',
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 4),
                              SizedBox(
                                height: 120,
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    width: 24,
                                    height: maxRevenue > 0
                                        ? math.max(
                                            2,
                                            (day['revenue'] as num) /
                                                maxRevenue *
                                                116,
                                          )
                                        : 2,
                                    decoration: BoxDecoration(
                                      color: (day['revenue'] as num) > 0
                                          ? brandOrange
                                          : const Color(0xFFE5E7EB),
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _short(day['date'] as String),
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
