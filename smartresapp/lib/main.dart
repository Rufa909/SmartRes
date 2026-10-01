import 'package:flutter/material.dart';

import 'restaurant_api.dart';
import 'staff_page.dart';

void main() => runApp(const MyApp());
const brand = Color(0xFFB74A2B);

String tien(int gia) =>
    '${gia.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')} đ';

class MyApp extends StatelessWidget {
  final RestaurantApi? api;
  const MyApp({super.key, this.api});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'SmartRes • Chặng 3',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: brand),
      scaffoldBackgroundColor: const Color(0xFFF9F7F3),
    ),
    home: MenuPage(api: api),
    routes: {'/staff': (_) => const StaffPage()},
  );
}

class MenuPage extends StatefulWidget {
  final RestaurantApi? api;
  const MenuPage({super.key, this.api});
  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  late final RestaurantApi api;
  List<MonAn> menu = [];
  bool loading = true, sending = false;
  String? loadError, sendError, requestId;
  Map<String, dynamic>? receipt;
  @override
  void initState() {
    super.initState();
    api = widget.api ?? RestaurantApi();
    loadMenu();
  }

  @override
  void dispose() {
    if (widget.api == null) api.client.close();
    super.dispose();
  }

  Future<void> loadMenu() async {
    setState(() {
      loading = true;
      loadError = null;
    });
    try {
      final result = await api.fetchMenu();
      if (!mounted) return;
      setState(() => menu = result);
    } catch (_) {
      if (!mounted) return;
      setState(
        () =>
            loadError = 'Không kết nối được menu. Kiểm tra backend và thử lại.',
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> sendOrder() async {
    if (sending || gioHang.isEmpty) return;
    setState(() {
      sending = true;
      sendError = null;
    });
    requestId ??= '${DateTime.now().microsecondsSinceEpoch}';
    try {
      final order = await api.createOrder(gioHang, requestId!);
      if (!mounted) return;
      setState(() {
        receipt = order;
        gioHang.clear();
        requestId = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(
        () => sendError =
            'Chưa xác nhận gửi đơn. Giỏ vẫn được giữ. ${error.toString().replaceFirst('Exception: ', '')}',
      );
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> showOrders() async {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Đơn đã gửi • Bàn A06'),
        content: SizedBox(
          width: 450,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: api.fetchOrders(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text('Không tải được đơn. Đóng và thử lại.');
              }
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 80,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final orders = snapshot.data!
                  .where((o) => o['tableId'] == 'A06')
                  .toList()
                  .reversed
                  .toList();
              if (orders.isEmpty) return const Text('Chưa có đơn nào.');
              return SizedBox(
                height: 350,
                child: ListView(
                  children: orders
                      .map(
                        (o) => ListTile(
                          title: Text(
                            '${o['orderCode']} • ${tien(o['totalAmount'] as int)}',
                          ),
                          subtitle: Text(
                            'Đã tiếp nhận\n${(o['items'] as List).map((i) => '${i['name']} × ${i['quantity']}').join('\n')}',
                          ),
                        ),
                      )
                      .toList(),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  // setState báo Flutter vẽ lại khi dữ liệu thay đổi.
  final Map<MonAn, int> gioHang = {};
  String danhMuc = 'Tất cả', tuKhoa = '';
  int trang = 0;
  int get soMon => gioHang.values.fold(0, (tong, sl) => tong + sl);
  int get tongTien =>
      gioHang.entries.fold(0, (tong, e) => tong + e.key.gia * e.value);
  void doiSoLuong(MonAn mon, int thayDoi) {
    if (!mon.conHang || sending) return;
    if ((gioHang[mon] ?? 0) + thayDoi > 99) return;
    setState(() {
      requestId = null;
      sendError = null;
      final moi = (gioHang[mon] ?? 0) + thayDoi;
      if (moi <= 0) {
        gioHang.remove(mon);
      } else {
        gioHang[mon] = moi;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ketQua = menu
        .where(
          (m) =>
              (danhMuc == 'Tất cả' || m.danhMuc == danhMuc) &&
              m.ten.toLowerCase().contains(tuKhoa.toLowerCase()),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9F7F3),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SmartRes', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('Thực hành gọi món • Bàn A06', style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Đơn đã gửi',
            onPressed: showOrders,
            icon: const Icon(Icons.receipt_long),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : loadError != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(loadError!),
                      ),
                      FilledButton(
                        onPressed: loadMenu,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                )
              : trang == 0
              ? Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Hôm nay ăn gì?',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text('Chọn món yêu thích cho bàn của bạn.'),
                          const SizedBox(height: 16),
                          TextField(
                            onChanged: (v) => setState(() => tuKhoa = v),
                            decoration: InputDecoration(
                              hintText: 'Tìm món ăn…',
                              prefixIcon: const Icon(Icons.search),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children:
                                  ['Tất cả', 'Khai vị', 'Món chính', 'Đồ uống']
                                      .map(
                                        (cat) => Padding(
                                          padding: const EdgeInsets.only(
                                            right: 8,
                                          ),
                                          child: ChoiceChip(
                                            label: Text(cat),
                                            selected: danhMuc == cat,
                                            onSelected: (_) =>
                                                setState(() => danhMuc = cat),
                                          ),
                                        ),
                                      )
                                      .toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ketQua.isEmpty
                          ? const Center(child: Text('Không tìm thấy món.'))
                          : LayoutBuilder(
                              builder: (context, size) => GridView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  4,
                                  20,
                                  20,
                                ),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: size.maxWidth >= 760
                                          ? 3
                                          : size.maxWidth < 350
                                          ? 1
                                          : 2,
                                      mainAxisExtent: 240,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                    ),
                                itemCount: ketQua.length,
                                itemBuilder: (_, i) => monCard(ketQua[i]),
                              ),
                            ),
                    ),
                  ],
                )
              : gioHangView(),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (soMon > 0 && trang == 0)
            Container(
              color: const Color(0xFFF1E6DD),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$soMon món • ${tien(tongTien)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  FilledButton(
                    onPressed: () => setState(() => trang = 1),
                    child: const Text('Xem giỏ hàng'),
                  ),
                ],
              ),
            ),
          NavigationBar(
            selectedIndex: trang,
            onDestinationSelected: (v) => setState(() => trang = v),
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.restaurant_menu),
                label: 'Thực đơn',
              ),
              NavigationDestination(
                icon: Badge(
                  label: Text('$soMon'),
                  isLabelVisible: soMon > 0,
                  child: const Icon(Icons.shopping_bag_outlined),
                ),
                label: 'Giỏ hàng',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget monCard(MonAn mon) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    color: Colors.white,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 90,
          width: double.infinity,
          color: const Color(0xFFF3E9DE),
          alignment: Alignment.center,
          child: Text(mon.emoji, style: const TextStyle(fontSize: 48)),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mon.ten,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Text(
                  tien(mon.gia),
                  style: const TextStyle(
                    color: brand,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: mon.conHang ? () => doiSoLuong(mon, 1) : null,
                    child: Text(
                      mon.conHang
                          ? 'Thêm${gioHang.containsKey(mon) ? ' (${gioHang[mon]})' : ''}'
                          : 'Hết món',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
  Widget gioHangView() {
    if (gioHang.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shopping_bag_outlined, size: 64, color: brand),
            if (receipt != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Đã gửi đơn ${receipt!['orderCode']}\nTổng: ${tien(receipt!['totalAmount'] as int)}\nServer đã tiếp nhận đơn.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: brand,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            const Text(
              'Giỏ hàng đang trống',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => setState(() => trang = 0),
              child: const Text('Chọn món ngay'),
            ),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Món bạn đã chọn',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        const Text('Bàn A06 • Chưa gửi bếp'),
        const SizedBox(height: 20),
        ...gioHang.entries.map(
          (e) => Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${e.key.emoji}  ${e.key.ten}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(child: Text(tien(e.key.gia * e.value))),
                      IconButton(
                        tooltip: 'Giảm ${e.key.ten}',
                        onPressed: () => doiSoLuong(e.key, -1),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text('${e.value}'),
                      IconButton(
                        tooltip: 'Tăng ${e.key.ten}',
                        onPressed: () => doiSoLuong(e.key, 1),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Tạm tính', style: TextStyle(fontSize: 20)),
            Text(
              tien(tongTien),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: brand,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (sendError != null)
          Text(sendError!, style: const TextStyle(color: Colors.red)),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: sending ? null : sendOrder,
          icon: sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send),
          label: Text(sending ? 'Đang gửi…' : 'Gửi đơn gọi món'),
        ),
        const SizedBox(height: 12),
        const Text(
          'Bản học: đơn đã gửi được lưu tại server. Giỏ chưa gửi sẽ mất khi tải lại trang.',
        ),
      ],
    );
  }
}
