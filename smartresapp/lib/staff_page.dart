import 'package:flutter/material.dart';

const staffGreen = Color(0xFF176B53);

class StaffTable {
  final String code, area;
  int guests;
  String status;
  StaffTable(this.code, this.area, this.status, this.guests);
}

class StaffPage extends StatefulWidget {
  const StaffPage({super.key});
  @override
  State<StaffPage> createState() => _StaffPageState();
}

class _StaffPageState extends State<StaffPage> {
  int tab = 0;
  String area = 'Tất cả';
  final tables = [
    StaffTable('A01', 'Tầng 1', 'Trống', 0),
    StaffTable('A02', 'Tầng 1', 'Đang phục vụ', 2),
    StaffTable('A03', 'Tầng 1', 'Chờ thanh toán', 4),
    StaffTable('A04', 'Tầng 1', 'Trống', 0),
    StaffTable('A05', 'Tầng 1', 'Đang phục vụ', 3),
    StaffTable('A06', 'Tầng 1', 'Đang phục vụ', 4),
    StaffTable('B01', 'Tầng 2', 'Trống', 0),
    StaffTable('B02', 'Tầng 2', 'Đang phục vụ', 2),
  ];
  final ready = <Map<String, String>>[
    {'table': 'A06', 'dish': 'Cơm chiên hải sản', 'qty': '2 phần'},
    {'table': 'A02', 'dish': 'Gỏi cuốn tôm', 'qty': '1 phần'},
  ];
  final pending = <String>[];
  Color statusColor(String status) => status == 'Trống' ? staffGreen
      : status == 'Chờ thanh toán' ? const Color(0xFFB06B16) : const Color(0xFF3665AC);

  @override
  Widget build(BuildContext context) => Theme(
    data: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: staffGreen),
      scaffoldBackgroundColor: const Color(0xFFF5F7F6)),
    child: Scaffold(
      appBar: AppBar(backgroundColor: const Color(0xFFF5F7F6), toolbarHeight: 76,
        title: const Row(children: [
          CircleAvatar(backgroundColor: staffGreen, child: Text('NL', style: TextStyle(color: Colors.white))),
          SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('NHÂN VIÊN', style: TextStyle(fontSize: 10, letterSpacing: 1.4, color: staffGreen)),
            Text('Nhung L', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
          ]),
        ]),
        actions: [IconButton(tooltip: 'Món chờ phục vụ', onPressed: () => setState(() => tab = 1),
          icon: Badge(label: Text('${ready.length}'), isLabelVisible: ready.isNotEmpty,
            child: const Icon(Icons.notifications_none))), const SizedBox(width: 12)]),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 900),
        child: tab == 0 ? tableView() : tab == 1 ? orderView() : profileView())),
      bottomNavigationBar: NavigationBar(selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i), destinations: const [
          NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view), label: 'Sơ đồ bàn'),
          NavigationDestination(icon: Icon(Icons.room_service_outlined), selectedIcon: Icon(Icons.room_service), label: 'Phục vụ'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Cá nhân'),
        ]),
    ),
  );

  Widget tableView() => ListView(padding: const EdgeInsets.all(20), children: [
    Row(children: [const Expanded(child: Text('Ca làm hôm nay', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800))),
      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: const Color(0xFFE1EEE7), borderRadius: BorderRadius.circular(20)),
        child: const Text('● Đang làm', style: TextStyle(color: staffGreen, fontSize: 12)))]),
    const SizedBox(height: 5),
    const Text('Ca chiều · 14:00 – 22:00', style: TextStyle(color: Colors.black54)),
    const SizedBox(height: 12),
    const Text('BẢN XEM THỬ • Dữ liệu nhân viên mô phỏng', style: TextStyle(fontSize: 11, color: Colors.black54)),
    const SizedBox(height: 20),
    Row(children: [metric('${tables.where((t) => t.status != 'Trống').length}', 'Bàn đang dùng'),
      const SizedBox(width: 10), metric('${ready.length}', 'Món chờ phục vụ')]),
    if (ready.isNotEmpty) ...[
      const SizedBox(height: 18),
      InkWell(onTap: () => setState(() => tab = 1), borderRadius: BorderRadius.circular(16),
        child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(
          color: const Color(0xFFFFF1D9), borderRadius: BorderRadius.circular(16)),
          child: Row(children: [const Icon(Icons.room_service, color: Color(0xFFB06B16)), const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${ready.length} món đã xong, sẵn sàng phục vụ', style: const TextStyle(fontWeight: FontWeight.bold)),
              const Text('Chạm để xem món và bàn nhận', style: TextStyle(fontSize: 12))])),
            const Icon(Icons.chevron_right)]))),
    ],
    const SizedBox(height: 24),
    const Text('Sơ đồ bàn', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
    const SizedBox(height: 12),
    Wrap(spacing: 8, children: ['Tất cả', 'Tầng 1', 'Tầng 2'].map((a) => ChoiceChip(
      label: Text(a), selected: area == a, onSelected: (_) => setState(() => area = a))).toList()),
    const SizedBox(height: 12),
    const Text('Chọn bàn để xem chi tiết hoặc gọi thêm món.', style: TextStyle(fontSize: 12, color: Colors.black54)),
    const SizedBox(height: 14),
    LayoutBuilder(builder: (context, size) {
      final visible = tables.where((t) => area == 'Tất cả' || t.area == area).toList();
      return GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: size.maxWidth > 650 ? 4 : 2,
          mainAxisExtent: 158, crossAxisSpacing: 12, mainAxisSpacing: 12),
        itemCount: visible.length, itemBuilder: (_, i) {
          final t = visible[i]; final color = statusColor(t.status);
          return Card(color: Colors.white, elevation: 0, margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: color.withValues(alpha: .22))),
            child: InkWell(borderRadius: BorderRadius.circular(18), onTap: () => tableDetails(t),
              child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Expanded(child: Text(t.code, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800))),
                  Icon(Icons.table_restaurant_outlined, color: color)]),
                const SizedBox(height: 10),
                Text(t.status, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
                const Spacer(), Text(t.guests == 0 ? '${t.area} · 4 chỗ' : '${t.area} · ${t.guests} khách',
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ]))));
        });
    }),
  ]);

  Widget metric(String value, String label) => Expanded(child: Container(
    padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: staffGreen)),
      Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
    ])));

  void tableDetails(StaffTable t) => showModalBottomSheet<void>(context: context, isScrollControlled: true,
    showDragHandle: true, builder: (sheetContext) => SafeArea(child: Padding(padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Bàn ${t.code}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        Text('${t.status} · ${t.area}', style: TextStyle(color: statusColor(t.status))),
        const SizedBox(height: 18),
        Text(t.status == 'Trống' ? 'Bàn sẵn sàng đón khách.' : '${t.guests} khách đang dùng bàn.'),
        const SizedBox(height: 20),
        FilledButton.icon(icon: Icon(t.status == 'Trống' ? Icons.group_add : Icons.add),
          label: Text(t.status == 'Trống' ? 'Nhận bàn · 2 khách (demo)' : 'Gọi thêm món'), onPressed: () {
            Navigator.pop(sheetContext);
            if (t.status == 'Trống') { setState(() { t.status = 'Đang phục vụ'; t.guests = 2; }); }
            else { chooseDish(t); }
          }),
        if (t.status == 'Đang phục vụ') OutlinedButton(onPressed: () {
          setState(() => t.status = 'Chờ thanh toán'); Navigator.pop(sheetContext);
        }, child: const Text('Yêu cầu thanh toán (demo)')),
        const SizedBox(height: 10),
        const Text('Thao tác mô phỏng, chưa kết nối dữ liệu vận hành.', style: TextStyle(fontSize: 12, color: Colors.black54)),
      ]))));

  void chooseDish(StaffTable t) => showModalBottomSheet<void>(context: context, showDragHandle: true,
    builder: (sheetContext) => SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: Column(
      mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Gọi món · Bàn ${t.code}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const Text('Chọn một món để tạo yêu cầu mẫu.'),
        const SizedBox(height: 12),
        ...['Cơm chiên hải sản', 'Gỏi cuốn tôm', 'Trà đào cam sả'].map((dish) => ListTile(
          contentPadding: EdgeInsets.zero, title: Text(dish), subtitle: const Text('1 phần'),
          trailing: const Icon(Icons.add_circle_outline, color: staffGreen), onTap: () {
            setState(() => pending.add('Bàn ${t.code} · $dish × 1'));
            Navigator.pop(sheetContext);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã thêm yêu cầu mẫu. Xem trong mục Phục vụ.')));
          })),
      ]))));

  Widget orderView() => ListView(padding: const EdgeInsets.all(20), children: [
    const Text('Món chờ phục vụ', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
    const SizedBox(height: 8), const Text('Dữ liệu mô phỏng · Chưa cập nhật từ bếp'),
    const SizedBox(height: 20),
    if (ready.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('Đã phục vụ hết các món mẫu.')),
    ...ready.map((item) => Card(color: Colors.white, child: Padding(padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Bàn ${item['table']}', style: const TextStyle(color: staffGreen, fontWeight: FontWeight.w800, fontSize: 20)),
        const SizedBox(height: 6), Text(item['dish']!, style: const TextStyle(fontSize: 17)),
        Text('${item['qty']} · Bếp đã hoàn thành'), const SizedBox(height: 14),
        FilledButton.icon(onPressed: () => setState(() => ready.remove(item)),
          icon: const Icon(Icons.check), label: const Text('Xác nhận đã phục vụ')),
      ])))),
    if (pending.isNotEmpty) ...[
      const SizedBox(height: 24), const Text('Yêu cầu gọi món mẫu', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ...pending.map((p) => ListTile(title: Text(p), subtitle: const Text('Đã ghi nhận trên giao diện · Chưa gửi backend'))),
    ],
  ]);

  Widget profileView() => ListView(padding: const EdgeInsets.all(24), children: [
    const CircleAvatar(radius: 42, backgroundColor: staffGreen, child: Text('NL', style: TextStyle(fontSize: 28, color: Colors.white))),
    const SizedBox(height: 20), const Center(child: Text('Nhung L', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold))),
    const Center(child: Text('Nhân viên phục vụ · Tài khoản mẫu')),
    const SizedBox(height: 28),
    const ListTile(leading: Icon(Icons.schedule), title: Text('Ca chiều'), subtitle: Text('14:00 – 22:00')),
    const ListTile(leading: Icon(Icons.location_on_outlined), title: Text('Khu vực phụ trách'), subtitle: Text('Tầng 1 và tầng 2')),
    const ListTile(leading: Icon(Icons.info_outline), title: Text('Bản xem thử giao diện'), subtitle: Text('Thay đổi mất khi tải lại trang. Chưa có đăng nhập và phân quyền.')),
  ]);
}
