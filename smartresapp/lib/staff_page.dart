import 'dart:async';

import 'package:flutter/material.dart';

import 'staff_api.dart';
import 'kitchen_page.dart';
import 'restaurant_theme.dart';
import 'order_catalogue.dart';
import 'ready_alert.dart';

const staffGreen = brandOrange;
String staffMoney(num value) =>
    '${value.toInt().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')} đ';
String tableStatus(String s) => switch (s) {
  'available' => 'Trống',
  'dining' => 'Đang phục vụ',
  'waiting_payment' => 'Chờ thanh toán',
  _ => 'Tạm khóa',
};
String itemStatus(String s) => switch (s) {
  'preparing' => 'Chờ bếp',
  'cooking' => 'Đang nấu',
  'completed' => 'Chờ phục vụ',
  'served' => 'Đã phục vụ',
  _ => s,
};

class StaffPage extends StatefulWidget {
  final StaffApi? api;
  final bool autoRefresh;
  const StaffPage({super.key, this.api, this.autoRefresh = true});
  @override
  State<StaffPage> createState() => _StaffPageState();
}

class _StaffPageState extends State<StaffPage> {
  late final StaffApi api;
  Timer? timer;
  int tab = 0;
  String area = 'Tất cả';
  bool initialLoading = true, refreshing = false, busy = false;
  String? error;
  final readyTracker = ReadyTracker();
  final alert = ReadyAlert();
  bool soundEnabled = true;
  String? alertMessage;
  String tableQuery = '';
  List<Map<String, dynamic>> tables = [], menu = [], items = [];
  List<Map<String, dynamic>> get ready =>
      items.where((i) => i['status'] == 'completed').toList();

  @override
  void initState() {
    super.initState();
    api = widget.api ?? StaffApi();
    unawaited(startAlerts());
    if (widget.autoRefresh) {
      timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!busy) refresh();
      });
    }
  }

  Future<void> startAlerts() async {
    final enabled = await alert.enabled();
    if (!mounted) return;
    setState(() => soundEnabled = enabled);
    await refresh();
  }

  Future<void> testSound() async {
    final played = await alert.play();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          played
              ? 'Đã phát âm thử. Âm lượng phụ thuộc mức thông báo của thiết bị.'
              : 'Thiết bị này chưa phát được âm báo.',
        ),
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    if (widget.api == null) api.client.close();
    super.dispose();
  }

  Future<void> refresh() async {
    if (refreshing) return;
    refreshing = true;
    try {
      final data = await api.snapshot();
      if (!mounted) return;
      final nextItems = (data['items'] as List).cast<Map<String, dynamic>>();
      final newlyReady = readyTracker.update(nextItems);
      setState(() {
        tables = (data['tables'] as List).cast<Map<String, dynamic>>();
        menu = (data['menu'] as List).cast<Map<String, dynamic>>();
        items = nextItems;
        if (newlyReady.isNotEmpty) {
          alertMessage =
              'Bếp đã xong ${newlyReady.length} dòng món · Bàn ${newlyReady.map((i) => i['tableCode']).toSet().join(', ')}';
        }
        error = null;
      });
      if (newlyReady.isNotEmpty && soundEnabled) {
        final played = await alert.play();
        if (mounted && !played) {
          setState(
            () => alertMessage = '$alertMessage · Không phát được âm thanh',
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      refreshing = false;
      if (mounted) setState(() => initialLoading = false);
    }
  }

  Future<void> mutate(Future<void> Function() action, String message) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      await refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Color statusColor(String s) => s == 'available'
      ? staffGreen
      : s == 'waiting_payment'
      ? const Color(0xFFB06B16)
      : const Color(0xFF3665AC);

  @override
  Widget build(BuildContext context) => Theme(
    data: restaurantTheme(),
    child: Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        toolbarHeight: 76,
        title: const Row(
          children: [
            CircleAvatar(
              backgroundColor: staffGreen,
              child: Icon(Icons.badge_outlined, color: Colors.white),
            ),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SMARTRES',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.4,
                    color: staffGreen,
                  ),
                ),
                Text(
                  'Nhân viên',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Mở màn hình bếp',
            onPressed: () async {
              await Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => const KitchenPage()),
              );
              if (mounted) await refresh();
            },
            icon: const Icon(Icons.soup_kitchen_outlined),
          ),
          IconButton(
            tooltip: 'Tải lại dữ liệu',
            onPressed: refresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Món chờ phục vụ',
            onPressed: () => setState(() => tab = 1),
            icon: Badge(
              label: Text('${ready.length}'),
              isLabelVisible: ready.isNotEmpty,
              child: const Icon(Icons.notifications_none),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (busy) const LinearProgressIndicator(),
          if (alertMessage != null && ready.isNotEmpty)
            MaterialBanner(
              backgroundColor: const Color(0xFFFFEEE9),
              content: Text(alertMessage!),
              leading: const Icon(Icons.room_service, color: brandOrange),
              actions: [
                TextButton(
                  onPressed: () => setState(() {
                    tab = 1;
                    alertMessage = null;
                  }),
                  child: const Text('Xem món'),
                ),
              ],
            ),
          if (error != null)
            MaterialBanner(
              content: Text('$error Dữ liệu đang hiển thị có thể đã cũ.'),
              actions: [
                TextButton(onPressed: refresh, child: const Text('Thử lại')),
              ],
            ),
          Expanded(
            child: AbsorbPointer(
              absorbing: busy,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: initialLoading
                      ? const Center(child: CircularProgressIndicator())
                      : tab == 0
                      ? tableView()
                      : tab == 1
                      ? orderView()
                      : profileView(),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'Sơ đồ bàn',
          ),
          NavigationDestination(
            icon: Icon(Icons.room_service_outlined),
            selectedIcon: Icon(Icons.room_service),
            label: 'Phục vụ',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Cá nhân',
          ),
        ],
      ),
    ),
  );
  Widget tableView() => RefreshIndicator(
    onRefresh: refresh,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Khu vực phục vụ',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          error == null ? '● Đã kết nối dữ liệu' : '● Mất kết nối',
          style: TextStyle(
            color: error == null ? staffGreen : Colors.red,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            metric(
              '${tables.where((t) => t['status'] != 'available').length}',
              'Bàn đang dùng',
            ),
            const SizedBox(width: 10),
            metric('${ready.length}', 'Món chờ phục vụ'),
          ],
        ),
        if (ready.isNotEmpty) ...[
          const SizedBox(height: 18),
          Card(
            color: const Color(0xFFFFF1D9),
            child: ListTile(
              onTap: () => setState(() => tab = 1),
              leading: const Icon(Icons.room_service),
              title: Text('${ready.length} món đã xong'),
              subtitle: const Text('Chạm để xem bàn nhận'),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
        ],
        const SizedBox(height: 24),
        const Text(
          'Sơ đồ bàn',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children:
              ['Tất cả', ...tables.map((t) => t['area'] as String).toSet()]
                  .map(
                    (a) => ChoiceChip(
                      label: Text(a),
                      selected: area == a,
                      onSelected: (_) => setState(() => area = a),
                    ),
                  )
                  .toList(),
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: (value) => setState(() => tableQuery = value),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Tìm bàn, ví dụ A03',
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Chọn bàn để nhận khách hoặc gọi thêm món.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 14),
        if (tables.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Chưa tải được danh sách bàn.'),
          ),
        LayoutBuilder(
          builder: (context, size) {
            final visible = tables
                .where(
                  (t) =>
                      (area == 'Tất cả' || t['area'] == area) &&
                      matchesSearch(t['code'] as String, tableQuery),
                )
                .toList();
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: size.maxWidth > 650 ? 4 : 2,
                mainAxisExtent: 158,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: visible.length,
              itemBuilder: (_, i) {
                final t = visible[i];
                final color = statusColor(t['status'] as String);
                return Card(
                  color: Colors.white,
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(color: color.withValues(alpha: .22)),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => tableDetails(t),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  t['code'] as String,
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
                            tableStatus(t['status'] as String),
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${t['area']} · ${t['guests'] == 0 ? '${t['seats']} chỗ' : '${t['guests']} khách'}',
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
  );
  Widget metric(String value, String label) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: staffGreen,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    ),
  );

  void tableDetails(Map<String, dynamic> t) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Bàn ${t['code']}',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            ),
            Text('${tableStatus(t['status'] as String)} · ${t['area']}'),
            const SizedBox(height: 18),
            Text(
              t['status'] == 'available'
                  ? 'Bàn sẵn sàng đón khách.'
                  : '${t['guests']} khách đang dùng bàn.',
            ),
            const SizedBox(height: 20),
            if (t['status'] == 'available')
              FilledButton.icon(
                icon: const Icon(Icons.group_add),
                label: const Text('Nhận bàn'),
                onPressed: () {
                  Navigator.pop(sheetContext);
                  seatTable(t);
                },
              ),
            if (t['status'] == 'dining') ...[
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Gọi thêm món'),
                onPressed: () {
                  Navigator.pop(sheetContext);
                  chooseDish(t);
                },
              ),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  mutate(
                    () => api.payment(t['id'] as int),
                    'Đã gửi yêu cầu thanh toán.',
                  );
                },
                child: const Text('Yêu cầu thanh toán'),
              ),
            ],
            if (t['status'] == 'waiting_payment')
              const Text('Bàn đang chờ thu ngân thanh toán.'),
          ],
        ),
      ),
    ),
  );

  Future<void> seatTable(Map<String, dynamic> t) async {
    int guests = 1;
    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Nhận bàn ${t['code']}'),
          content: DropdownButtonFormField<int>(
            initialValue: guests,
            decoration: const InputDecoration(labelText: 'Số khách'),
            items: List.generate(
              t['seats'] as int,
              (i) =>
                  DropdownMenuItem(value: i + 1, child: Text('${i + 1} khách')),
            ),
            onChanged: (v) => setLocal(() => guests = v!),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, guests),
              child: const Text('Xác nhận'),
            ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) {
      await mutate(
        () => api.seat(t['id'] as int, selected),
        'Đã nhận bàn ${t['code']}.',
      );
    }
  }

  Future<void> chooseDish(Map<String, dynamic> t) async {
    final sent = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => OrderSheet(table: t, menu: menu, api: api),
      ),
    );
    if (sent == true && mounted) {
      await refresh();
      if (mounted) setState(() => tab = 1);
    }
  }

  Widget orderView() => RefreshIndicator(
    onRefresh: refresh,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Món chờ phục vụ',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text('Kéo xuống để cập nhật đơn và trạng thái món.'),
        const SizedBox(height: 20),
        if (ready.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('Chưa có món bếp đã hoàn thành.'),
          ),
        ...ready.map(
          (item) => Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Bàn ${item['tableCode']}',
                    style: const TextStyle(
                      color: staffGreen,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item['name'] as String,
                    style: const TextStyle(fontSize: 17),
                  ),
                  Text('${item['quantity']} phần · Bếp đã hoàn thành'),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () => mutate(
                      () => api.serve(item['id'] as int),
                      'Đã xác nhận phục vụ.',
                    ),
                    icon: const Icon(Icons.check),
                    label: const Text('Xác nhận đã phục vụ'),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Các món đã gọi',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text('Chưa có đơn. Hãy nhận bàn và gọi món.'),
          ),
        ...items.map(
          (i) => Card(
            color: Colors.white,
            child: ListTile(
              title: Text(
                'Bàn ${i['tableCode']} · ${i['name']} × ${i['quantity']}',
              ),
              subtitle: Text(
                '${itemStatus(i['status'] as String)} · ${staffMoney(num.parse(i['unitPrice'].toString()) * (i['quantity'] as int))}',
              ),
            ),
          ),
        ),
      ],
    ),
  );
  Widget profileView() => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      SwitchListTile(
        title: const Text('Âm báo món hoàn thành'),
        subtitle: const Text(
          'Báo 3 tiếng khi có món mới sẵn sàng, trong lúc app đang mở.',
        ),
        value: soundEnabled,
        onChanged: (v) async {
          await alert.setEnabled(v);
          if (mounted) setState(() => soundEnabled = v);
        },
      ),
      OutlinedButton.icon(
        onPressed: testSound,
        icon: const Icon(Icons.volume_up),
        label: const Text('Thử âm báo'),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Tăng âm lượng thông báo trên thiết bị để nghe rõ. Chưa hỗ trợ báo khi đóng app hoặc khóa màn hình.',
        ),
      ),
      CircleAvatar(
        radius: 42,
        backgroundColor: staffGreen,
        child: Icon(Icons.badge_outlined, size: 36, color: Colors.white),
      ),
      SizedBox(height: 20),
      Center(
        child: Text(
          'SmartRes Nhân viên',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
      SizedBox(height: 24),
      ListTile(
        leading: Icon(Icons.storage),
        title: Text('Dữ liệu được lưu trên máy chủ'),
        subtitle: Text('Bàn, menu và đơn hàng đồng bộ từ MySQL.'),
      ),
      ListTile(
        leading: Icon(Icons.info_outline),
        title: Text('Bản phát triển nội bộ'),
        subtitle: Text('Chưa cấu hình đăng nhập và phân quyền nhân viên.'),
      ),
    ],
  );
}

class OrderSheet extends StatefulWidget {
  final Map<String, dynamic> table;
  final List<Map<String, dynamic>> menu;
  final StaffApi api;
  const OrderSheet({
    super.key,
    required this.table,
    required this.menu,
    required this.api,
  });
  @override
  State<OrderSheet> createState() => _OrderSheetState();
}

class _OrderSheetState extends State<OrderSheet> {
  final Map<int, int> cart = {};
  bool sending = false;
  String? error, requestId;
  num get total => widget.menu.fold<num>(
    0,
    (v, m) => v + (m['price'] as num) * (cart[m['id']] ?? 0),
  );
  void change(int id, int delta) {
    if (sending) return;
    setState(() {
      final q = (cart[id] ?? 0) + delta;
      if (q <= 0) {
        cart.remove(id);
      } else if (q <= 99) {
        cart[id] = q;
      }
      requestId = null;
      error = null;
    });
  }

  Future<void> send() async {
    if (sending || cart.isEmpty) return;
    setState(() {
      sending = true;
      error = null;
    });
    requestId ??= newRequestId();
    try {
      final result = await widget.api.order(
        widget.table['id'] as int,
        cart,
        requestId!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã lưu đơn ${result['orderCode']} · ${staffMoney(result['totalAmount'] as num)}',
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => error = '${e.toString()} Giỏ vẫn được giữ để thử lại.');
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !sending,
    child: OrderCatalogue(
      table: widget.table,
      menu: widget.menu,
      cart: cart,
      sending: sending,
      error: error,
      total: total,
      change: change,
      send: send,
    ),
  );
}
