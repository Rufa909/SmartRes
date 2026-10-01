import 'dart:async';
import 'package:flutter/material.dart';
import 'staff_api.dart';

const kitchenBlue = Color(0xFF254C76);

class KitchenPage extends StatefulWidget {
  final StaffApi? api;
  final bool autoRefresh;
  const KitchenPage({super.key, this.api, this.autoRefresh = true});
  @override
  State<KitchenPage> createState() => _KitchenPageState();
}

class _KitchenPageState extends State<KitchenPage> {
  late final StaffApi api;
  Timer? timer;
  Future<void>? refreshTask;
  bool loading = true, saving = false;
  String filter = 'preparing';
  String? error;
  List<Map<String, dynamic>> items = [];
  static const labels = {
    'preparing': 'Chờ bếp', 'cooking': 'Đang nấu', 'completed': 'Chờ phục vụ',
  };

  @override
  void initState() {
    super.initState();
    api = widget.api ?? StaffApi();
    refresh();
    if (widget.autoRefresh) timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!saving) refresh();
    });
  }
  @override
  void dispose() {
    timer?.cancel();
    if (widget.api == null) api.client.close();
    super.dispose();
  }
  Future<void> refresh() => refreshTask ??= load().whenComplete(() => refreshTask = null);
  Future<void> load() async {
    try {
      final data = await api.snapshot();
      if (!mounted) return;
      final next = (data['items'] as List).cast<Map<String, dynamic>>()
        .where((i) => labels.containsKey(i['status'])).toList()
        ..sort((a,b) => (a['createdAt'] as String).compareTo(b['createdAt'] as String));
      setState(() { items = next; error = null; });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
  Future<void> advance(Map<String, dynamic> item) async {
    if (saving) return;
    setState(() => saving = true);
    try {
      // Hoàn tất lần tải đang chạy trước khi thay đổi, tránh nhận lại ảnh chụp cũ.
      if (refreshTask != null) await refreshTask;
      final next = item['status'] == 'preparing' ? 'cooking' : 'completed';
      await api.kitchenStatus(item['id'] as int, next);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next == 'cooking'
        ? 'Đã bắt đầu nấu ${item['name']}.' : 'Món đã xong. Nhân viên có thể phục vụ.')));
      await refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      await refresh();
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
  String waitingTime(Map<String, dynamic> item) {
    final created = DateTime.tryParse(item['createdAt'] as String? ?? '');
    if (created == null) return '';
    final minutes = DateTime.now().difference(created).inMinutes;
    return minutes <= 0 ? 'Vừa nhận' : 'Nhận $minutes phút trước';
  }

  @override
  Widget build(BuildContext context) {
    final visible = items.where((i) => i['status'] == filter).toList();
    return Theme(data: ThemeData(useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: kitchenBlue), scaffoldBackgroundColor: const Color(0xFFF3F5F8)),
      child: Scaffold(
        appBar: AppBar(title: const Text('Bếp • SmartRes'), actions: [
          IconButton(tooltip: 'Tải lại bếp', onPressed: refresh, icon: const Icon(Icons.refresh)),
        ]),
        body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1000), child: Column(children: [
          if (saving) const LinearProgressIndicator(),
          if (error != null) MaterialBanner(content: Text('$error Danh sách có thể chưa cập nhật.'),
            actions: [TextButton(onPressed: refresh, child: const Text('Thử lại'))]),
          Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [Icon(Icons.soup_kitchen_outlined, color: kitchenBlue), SizedBox(width: 10),
              Text('Hàng đợi chế biến', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800))]),
            const SizedBox(height: 6),
            const Text('Ưu tiên món nhận trước. Trạng thái tự cập nhật.', style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 18),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: labels.entries.map((entry) => Padding(
              padding: const EdgeInsets.only(right: 8), child: ChoiceChip(
                label: Text('${entry.value} (${items.where((i) => i['status'] == entry.key).length})'),
                selected: filter == entry.key, onSelected: (_) => setState(() => filter = entry.key),
              ))).toList())),
          ])),
          Expanded(child: loading ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(onRefresh: refresh, child: ListView(
              physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                if (visible.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 64), child: Column(children: [
                  const Icon(Icons.task_alt, size: 56, color: kitchenBlue), const SizedBox(height: 16),
                  Text('Chưa có món ${labels[filter]!.toLowerCase()}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8), const Text('Đơn gọi món mới sẽ xuất hiện tại đây.'),
                ])),
                ...visible.map((item) => Card(color: Colors.white, elevation: 0, margin: const EdgeInsets.only(bottom: 14),
                  child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [Expanded(child: Text('Bàn ${item['tableCode']}', style: const TextStyle(color: kitchenBlue, fontSize: 22, fontWeight: FontWeight.w800))),
                      Text(waitingTime(item), style: const TextStyle(fontSize: 12, color: Colors.black54))]),
                    const SizedBox(height: 14),
                    Text('${item['quantity']} × ${item['name']}', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text('Đơn ${item['orderCode']}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                    const SizedBox(height: 16),
                    if (item['status'] != 'completed') FilledButton.icon(
                      onPressed: saving ? null : () => advance(item),
                      icon: Icon(item['status'] == 'preparing' ? Icons.local_fire_department : Icons.check_circle_outline),
                      label: Text(item['status'] == 'preparing' ? 'Bắt đầu nấu' : 'Hoàn thành món'),
                    ) else const Row(children: [Icon(Icons.room_service_outlined, color: kitchenBlue), SizedBox(width: 8),
                      Expanded(child: Text('Đã báo nhân viên · Chờ mang ra bàn'))]),
                  ])))),
              ],
            ))),
        ]))),
      ),
    );
  }
}
