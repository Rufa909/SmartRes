import 'dart:async';

import 'package:flutter/material.dart';

import 'staff_api.dart';
import 'restaurant_theme.dart';
import 'ready_alert.dart';

const kitchenBlue = brandOrange;

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
  String? tableFilter;
  DateTime? lastSynced;
  String query = '';
  bool overdueOnly = false;
  int age(Map<String, dynamic> item) => DateTime.now()
      .difference(
        DateTime.tryParse(item['createdAt'] as String? ?? '') ?? DateTime.now(),
      )
      .inMinutes;
  String? error;
  List<Map<String, dynamic>> items = [];
  final newItemAlert = ReadyAlert();
  final Set<int> knownItemIds = {};
  static const labels = {
    'preparing': 'Chờ bếp',
    'cooking': 'Đang nấu',
    'completed': 'Chờ phục vụ',
  };

  @override
  void initState() {
    super.initState();
    api = widget.api ?? StaffApi();
    refresh();
    if (widget.autoRefresh) {
      timer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (!saving) refresh();
      });
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    if (widget.api == null) api.client.close();
    super.dispose();
  }

  Future<void> refresh() =>
      refreshTask ??= load().whenComplete(() => refreshTask = null);
  Future<void> load() async {
    try {
      final data = await api.snapshot();
      if (!mounted) return;
      final next =
          (data['items'] as List)
              .cast<Map<String, dynamic>>()
              .where((i) => labels.containsKey(i['status']))
              .toList()
            ..sort(
              (a, b) => (a['createdAt'] as String).compareTo(
                b['createdAt'] as String,
              ),
            );
      final hasNewItems = next.any(
        (item) =>
            item['status'] == 'preparing' && !knownItemIds.contains(item['id']),
      );
      knownItemIds.addAll(next.map((item) => item['id'] as int));
      setState(() {
        items = next;
        lastSynced = DateTime.now();
        error = null;
      });
      if (hasNewItems) unawaited(newItemAlert.play());
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> advance(Map<String, dynamic> item) async {
    if (saving || error != null) return;
    setState(() => saving = true);
    try {
      // Hoàn tất lần tải đang chạy trước khi thay đổi, tránh nhận lại ảnh chụp cũ.
      if (refreshTask != null) await refreshTask;
      final next = item['status'] == 'preparing' ? 'cooking' : 'completed';
      await api.kitchenStatus(item['id'] as int, next);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            next == 'cooking'
                ? 'Đã bắt đầu nấu ${item['name']}.'
                : 'Món đã xong. Nhân viên có thể phục vụ.',
          ),
        ),
      );
      await refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
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
    final tables = items.map((i) => i['tableCode'] as String).toSet();
    if (tableFilter != null) tables.add(tableFilter!);
    final tableCodes = tables.toList()..sort();
    final scoped = items
        .where((i) => tableFilter == null || i['tableCode'] == tableFilter)
        .toList();
    final visible = scoped
        .where(
          (i) =>
              i['status'] == filter &&
              matchesSearch(
                '${i['name']} ${i['tableCode']} ${i['orderCode']}',
                query,
              ) &&
              (!overdueOnly || age(i) >= 15),
        )
        .toList();
    final portions = visible.fold<int>(
      0,
      (sum, i) => sum + (i['quantity'] as int),
    );
    final sync = lastSynced;
    return Theme(
      data: restaurantTheme(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bếp • SmartRes'),
          actions: [
            IconButton(
              tooltip: 'Tải lại bếp',
              onPressed: refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              children: [
                if (saving) const LinearProgressIndicator(),
                if (error != null)
                  MaterialBanner(
                    content: Text('$error Danh sách có thể chưa cập nhật.'),
                    actions: [
                      TextButton(
                        onPressed: refresh,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.soup_kitchen_outlined, color: kitchenBlue),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Hàng đợi chế biến',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Ưu tiên món nhận trước. Trạng thái tự cập nhật.',
                        style: TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        onChanged: (v) => setState(() => query = v),
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: 'Tìm món, bàn hoặc mã đơn',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                      const SizedBox(height: 6),
                      FilterChip(
                        label: const Text('Chờ từ 15 phút'),
                        selected: overdueOnly,
                        onSelected: (v) => setState(() => overdueOnly = v),
                      ),
                      DropdownButton<String>(
                        isExpanded: true,
                        value: tableFilter ?? '',
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text('Tất cả bàn'),
                          ),
                          ...tableCodes.map(
                            (code) => DropdownMenuItem(
                              value: code,
                              child: Text('Lọc bàn $code'),
                            ),
                          ),
                        ],
                        onChanged: (value) => setState(
                          () => tableFilter = value == '' ? null : value,
                        ),
                      ),
                      Text(
                        '$portions phần · ${visible.length} dòng món',
                        key: const ValueKey('kitchen-summary'),
                      ),
                      Text(
                        sync == null
                            ? 'Chưa đồng bộ dữ liệu'
                            : 'Đồng bộ lúc ${sync.hour.toString().padLeft(2, '0')}:${sync.minute.toString().padLeft(2, '0')}:${sync.second.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: labels.entries
                              .map(
                                (entry) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(
                                      '${entry.value} (${scoped.where((i) => i['status'] == entry.key).length})',
                                    ),
                                    selected: filter == entry.key,
                                    onSelected: (_) =>
                                        setState(() => filter = entry.key),
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
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                          onRefresh: refresh,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            children: [
                              if (visible.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 64,
                                  ),
                                  child: Column(
                                    children: [
                                      const Icon(
                                        Icons.task_alt,
                                        size: 56,
                                        color: kitchenBlue,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        error != null
                                            ? 'Chưa xác nhận được danh sách món'
                                            : 'Chưa có món ${labels[filter]!.toLowerCase()}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 19,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        error != null
                                            ? 'Kết nối lại rồi bấm Thử lại.'
                                            : 'Danh sách theo trạng thái và bàn đang chọn.',
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ...visible.map(
                                (item) => Card(
                                  color: Colors.white,
                                  elevation: 0,
                                  margin: const EdgeInsets.only(bottom: 14),
                                  child: Padding(
                                    padding: const EdgeInsets.all(18),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'Bàn ${item['tableCode']}',
                                                style: const TextStyle(
                                                  color: kitchenBlue,
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              waitingTime(item),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.black54,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 14),
                                        if (age(item) >= 15)
                                          Text(
                                            'Đã chờ ${age(item)} phút từ khi đặt',
                                            style: const TextStyle(
                                              color: Color(0xFFB45309),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        Text(
                                          '${item['quantity']} × ${item['name']}',
                                          style: const TextStyle(
                                            fontSize: 21,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        if ((item['note'] as String? ?? '')
                                            .isNotEmpty)
                                          Text(
                                            'Ghi chú: ${item['note']}',
                                            style: const TextStyle(
                                              color: Color(0xFFB45309),
                                            ),
                                          ),
                                        Text(
                                          'Đơn ${item['orderCode']}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.black54,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        if (item['status'] != 'completed')
                                          FilledButton.icon(
                                            onPressed: saving || error != null
                                                ? null
                                                : () => advance(item),
                                            icon: Icon(
                                              item['status'] == 'preparing'
                                                  ? Icons.local_fire_department
                                                  : Icons.check_circle_outline,
                                            ),
                                            label: Text(
                                              item['status'] == 'preparing'
                                                  ? 'Bắt đầu nấu'
                                                  : 'Hoàn thành món',
                                            ),
                                          )
                                        else
                                          const Row(
                                            children: [
                                              Icon(
                                                Icons.room_service_outlined,
                                                color: kitchenBlue,
                                              ),
                                              SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'Đã báo nhân viên · Chờ mang ra bàn',
                                                ),
                                              ),
                                            ],
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
