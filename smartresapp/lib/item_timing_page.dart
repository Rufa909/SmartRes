import 'dart:async';

import 'package:flutter/material.dart';

import 'invoice_document.dart';
import 'restaurant_theme.dart';
import 'staff_api.dart';

const timingStatuses = {
  'preparing': 'Chờ bếp',
  'cooking': 'Đang nấu',
  'completed': 'Chờ phục vụ',
  'served': 'Đã phục vụ',
};
String timingDuration(num? seconds) {
  if (seconds == null) return 'Chưa đủ mốc';
  final value = seconds.toInt();
  if (value < 60) return '$value giây';
  if (value < 3600) return '${value ~/ 60} phút ${value % 60} giây';
  return '${value ~/ 3600} giờ ${(value % 3600) ~/ 60} phút ${value % 60} giây';
}

String timingClock(dynamic value) => invoiceDate(value).split(' ').last;

Color timingColor(String status) => switch (status) {
  'preparing' => const Color(0xFFB06B16),
  'cooking' => brandOrange,
  'completed' => const Color(0xFF3366CC),
  _ => const Color(0xFF23886B),
};

class ItemTimingPage extends StatefulWidget {
  final StaffApi api;
  final bool autoRefresh;
  const ItemTimingPage({super.key, required this.api, this.autoRefresh = true});
  @override
  State<ItemTimingPage> createState() => _ItemTimingPageState();
}

class _ItemTimingPageState extends State<ItemTimingPage> {
  Timer? timer, searchTimer;
  List<Map<String, dynamic>> items = [];
  Map<String, dynamic> counts = {};
  bool loading = true, refreshing = false;
  String status = '', query = '';
  String? date, error, generatedAt;
  int total = 0, offset = 0, limit = 30, generation = 0;
  int filterCount(String key) {
    final keys = key == 'pending'
        ? ['preparing', 'cooking', 'completed']
        : key.isEmpty
        ? timingStatuses.keys
        : [key];
    return keys.fold<int>(
      0,
      (sum, status) => sum + ((counts[status] as num?)?.toInt() ?? 0),
    );
  }

  @override
  void initState() {
    super.initState();
    load();
    if (widget.autoRefresh) {
      timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!refreshing && !(searchTimer?.isActive ?? false)) load();
      });
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    searchTimer?.cancel();
    generation++;
    super.dispose();
  }

  Future<void> load() async {
    final request = ++generation;
    setState(() => refreshing = true);
    try {
      final data = await widget.api.itemTimings(
        status: status,
        query: query,
        date: date,
        offset: offset,
      );
      if (!mounted || request != generation) return;
      // If another device removed the last page, return to the previous page.
      if ((data['total'] as int) > 0 && offset >= (data['total'] as int)) {
        setState(
          () => offset =
              (((data['total'] as int) - 1) ~/ (data['limit'] as int)) *
              (data['limit'] as int),
        );
        await load();
        return;
      }
      setState(() {
        items = (data['items'] as List).cast<Map<String, dynamic>>();
        counts = data['counts'] as Map<String, dynamic>;
        total = data['total'] as int;
        if (total == 0) offset = 0;
        limit = data['limit'] as int;
        generatedAt = data['generatedAt'] as String;
        error = null;
      });
    } catch (e) {
      if (mounted && request == generation) {
        setState(() => error = e.toString());
      }
    } finally {
      if (mounted && request == generation) {
        setState(() {
          loading = false;
          refreshing = false;
        });
      }
    }
  }

  void filterChanged() {
    searchTimer?.cancel();
    setState(() {
      offset = 0;
      items = [];
      total = 0;
    });
    load();
  }

  Future<void> chooseDate() async {
    final now = DateTime.now().toUtc().add(const Duration(hours: 7));
    final chosen = await showDatePicker(
      context: context,
      initialDate: date == null
          ? DateTime(now.year, now.month, now.day)
          : DateTime.parse(date!),
      firstDate: DateTime(2000),
      lastDate: DateTime(2099, 12, 31),
    );
    if (chosen == null || !mounted) return;
    setState(
      () => date =
          '${chosen.year}-${chosen.month.toString().padLeft(2, '0')}-${chosen.day.toString().padLeft(2, '0')}',
    );
    filterChanged();
  }

  Widget durationRow(String label, dynamic seconds, {bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                timingDuration(seconds as num?),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      );
  Widget itemCard(Map<String, dynamic> item) {
    final durations = item['durations'] as Map<String, dynamic>;
    final itemStatus = item['status'] as String;
    final color = timingColor(itemStatus);
    final overdue =
        itemStatus != 'served' &&
        ((item['totalElapsedSeconds'] as num?) ?? 0) > 20 * 60;
    return Card(
      key: ValueKey('timing-item-${item['id']}'),
      color: Colors.white,
      child: ExpansionTile(
        key: PageStorageKey('timing-details-${item['id']}'),
        leading: Icon(Icons.restaurant_outlined, color: color),
        title: Text(
          '${item['name']} × ${item['quantity']}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bàn ${item['tableCode']} · ${timingStatuses[itemStatus]}',
              style: TextStyle(color: color),
            ),
            const SizedBox(height: 3),
            if (itemStatus != 'served')
              Text(
                item['createdAt'] == null
                    ? 'Gọi món: Chưa ghi nhận'
                    : 'Gọi: ${timingClock(item['createdAt'])}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            Text(
              itemStatus == 'served'
                  ? 'Tổng: ${timingDuration(durations['totalSeconds'] as num?)}'
                  : 'Đã chờ: ${timingDuration(item['totalElapsedSeconds'] as num?)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: overdue ? Colors.red : null,
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Bàn ${item['tableCode']} · ${item['orderCode']}'),
                if ((item['note'] as String? ?? '').isNotEmpty)
                  Text('Ghi chú: ${item['note']}'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      label: Text(
                        timingStatuses[itemStatus]!,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      backgroundColor: color.withValues(alpha: .1),
                      side: BorderSide.none,
                    ),
                    if (item['paymentStatus'] == 'paid')
                      const Chip(label: Text('Đã thanh toán')),
                  ],
                ),
                if (itemStatus != 'served') ...[
                  Text(
                    'Thời gian ở trạng thái hiện tại: ${item['currentStageElapsedSeconds'] == null ? 'Chưa ghi nhận mốc bắt đầu' : timingDuration(item['currentStageElapsedSeconds'] as num)}',
                  ),
                  Text(
                    'Tổng đã chờ: ${timingDuration(item['totalElapsedSeconds'] as num?)}',
                    style: TextStyle(
                      color: overdue ? Colors.red : null,
                      fontWeight: overdue ? FontWeight.bold : null,
                    ),
                  ),
                ],
                const Divider(height: 24),
                for (final milestone in {
                  'createdAt': 'Tạo món',
                  'cookingStartedAt': 'Bắt đầu nấu',
                  'completedAt': 'Nấu xong',
                  'servedAt': 'Đã bưng ra',
                }.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Expanded(child: Text(milestone.value)),
                        Text(
                          item[milestone.key] == null
                              ? 'Chưa ghi nhận'
                              : invoiceDate(item[milestone.key]),
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 24),
                durationRow(
                  'Thời gian chờ bếp',
                  durations['waitingKitchenSeconds'],
                ),
                durationRow('Thời gian nấu', durations['cookingSeconds']),
                durationRow(
                  'Thời gian chờ bưng',
                  durations['waitingServiceSeconds'],
                ),
                durationRow(
                  'Tổng thời gian ra món',
                  durations['totalSeconds'],
                  bold: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: restaurantTheme(),
    child: Scaffold(
      appBar: AppBar(
        title: const Text(
          'Thời gian và trạng thái ra món',
          maxLines: 2,
          style: TextStyle(fontSize: 18),
        ),
        actions: [
          IconButton(
            tooltip: 'Cập nhật thời gian món',
            onPressed: refreshing ? null : load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: RefreshIndicator(
            onRefresh: load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (refreshing) const LinearProgressIndicator(),
                if (error != null)
                  MaterialBanner(
                    content: Text('$error Dữ liệu có thể chưa cập nhật.'),
                    actions: [
                      TextButton(onPressed: load, child: const Text('Thử lại')),
                    ],
                  ),
                const Text(
                  'Theo dõi tiến độ từng món',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Giờ Việt Nam (GMT+7) · Tự cập nhật mỗi 5 giây',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Tìm món, bàn hoặc mã đơn',
                  ),
                  onChanged: (value) {
                    setState(() => query = value);
                    // Invalidate an earlier response as soon as the query changes.
                    generation++;
                    searchTimer?.cancel();
                    searchTimer = Timer(
                      const Duration(milliseconds: 350),
                      filterChanged,
                    );
                  },
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in {
                      '': 'Tất cả',
                      'pending': 'Đang chờ',
                      ...timingStatuses,
                    }.entries)
                      ChoiceChip(
                        label: Text(
                          '${entry.value} (${filterCount(entry.key)})',
                        ),
                        selected: status == entry.key,
                        onSelected: (_) {
                          setState(() => status = entry.key);
                          filterChanged();
                        },
                      ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: chooseDate,
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text(date == null ? 'Hôm nay' : 'Ngày tạo: $date'),
                    ),
                    if (date != null)
                      TextButton(
                        onPressed: () {
                          setState(() => date = null);
                          filterChanged();
                        },
                        child: const Text('Về hôm nay'),
                      ),
                  ],
                ),
                const Text(
                  'Chỉ hiện món được gọi trong ngày đang chọn. Món cũ thiếu thời điểm tạo không nằm trong bộ lọc ngày.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                if (generatedAt != null)
                  Text(
                    'Đồng bộ: ${invoiceDate(generatedAt)}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                const SizedBox(height: 12),
                Text(
                  '$total dòng món phù hợp',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (!loading && !refreshing && error == null && items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Không có món phù hợp.'),
                  ),
                ...items.map(itemCard),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: refreshing || error != null || offset == 0
                            ? null
                            : () {
                                setState(() => offset -= limit);
                                load();
                              },
                        child: const Text('Trang trước'),
                      ),
                    ),
                    Text('Trang ${offset ~/ limit + 1}'),
                    Expanded(
                      child: TextButton(
                        onPressed:
                            refreshing ||
                                error != null ||
                                offset + limit >= total
                            ? null
                            : () {
                                setState(() => offset += limit);
                                load();
                              },
                        child: const Text('Trang sau'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
