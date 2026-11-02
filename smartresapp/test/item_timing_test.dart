import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartresapp/item_timing_page.dart';
import 'package:smartresapp/staff_api.dart';

Map<String, dynamic> item({
  int id = 1,
  String status = 'served',
  bool missing = false,
}) => {
  'id': id,
  'name': 'Cơm gà',
  'quantity': 2,
  'tableCode': 'A01',
  'orderCode': 'SR-TIMING',
  'status': status,
  'paymentStatus': 'unpaid',
  'note': null,
  'createdAt': missing ? null : '2026-11-02T03:00:00Z',
  'cookingStartedAt': missing ? null : '2026-11-02T03:02:00Z',
  'completedAt': missing || status == 'cooking' ? null : '2026-11-02T03:07:00Z',
  'servedAt': missing || status == 'cooking' ? null : '2026-11-02T03:08:00Z',
  'durations': {
    'waitingKitchenSeconds': missing ? null : 120,
    'cookingSeconds': missing || status == 'cooking' ? null : 300,
    'waitingServiceSeconds': missing || status == 'cooking' ? null : 60,
    'totalSeconds': missing || status == 'cooking' ? null : 480,
  },
  'currentStageElapsedSeconds': status == 'cooking' ? 120 : null,
  'totalElapsedSeconds': missing ? null : 480,
};
Map<String, dynamic> data(
  Map<String, dynamic> row, {
  int total = 1,
  int limit = 30,
}) => {
  'items': [row],
  'total': total,
  'offset': 0,
  'limit': limit,
  'counts': {'preparing': 0, 'cooking': 1, 'completed': 0, 'served': 1},
  'generatedAt': '2026-11-02T03:08:00Z',
};
http.Response response(Object value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  testWidgets(
    'Chờ hơn 20 phút tô đỏ ở ba trạng thái, đúng 20 phút và món đã phục vụ không đỏ',
    (tester) async {
      var status = 'preparing';
      num? elapsed = 1200;
      final client = MockClient(
        (_) async => response(
          data({
            ...item(status: status),
            'totalElapsedSeconds': elapsed,
            if (status == 'served')
              'durations': {
                ...item()['durations'] as Map<String, dynamic>,
                'totalSeconds': 1800,
              },
          }),
        ),
      );
      addTearDown(client.close);
      await tester.pumpWidget(
        MaterialApp(
          home: ItemTimingPage(
            api: StaffApi(client: client),
            autoRefresh: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.text('Đã chờ: 20 phút 0 giây')).style!.color,
        isNot(Colors.red),
      );
      for (final state in ['preparing', 'cooking', 'completed']) {
        status = state;
        elapsed = 1201;
        await tester.tap(find.byTooltip('Cập nhật thời gian món'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<Text>(find.text('Đã chờ: 20 phút 1 giây')).style!.color,
          Colors.red,
        );
        expect(find.text('Gọi: 10:00:00'), findsOneWidget);
      }
      status = 'served';
      await tester.tap(find.byTooltip('Cập nhật thời gian món'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.text('Tổng: 30 phút 0 giây')).style!.color,
        isNot(Colors.red),
      );
      status = 'preparing';
      elapsed = null;
      await tester.tap(find.byTooltip('Cập nhật thời gian món'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.text('Đã chờ: Chưa đủ mốc')).style!.color,
        isNot(Colors.red),
      );
    },
  );

  testWidgets('Mặc định hôm nay, chọn ngày trước rồi quay về hôm nay', (
    tester,
  ) async {
    final requests = <String?>[];
    final client = MockClient((req) async {
      final day = req.url.queryParameters['date'];
      requests.add(day);
      return response(
        data({
          ...item(),
          'name': day == null ? 'Món hôm nay' : 'Món ngày trước',
        }),
      );
    });
    addTearDown(client.close);
    await tester.pumpWidget(
      MaterialApp(
        home: ItemTimingPage(api: StaffApi(client: client), autoRefresh: false),
      ),
    );
    await tester.pumpAndSettle();
    expect(requests.last, isNull);
    expect(find.text('Hôm nay'), findsOneWidget);
    expect(find.text('Tất cả ngày'), findsNothing);
    await tester.tap(find.text('Hôm nay'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    final previous = DateTime.now().subtract(const Duration(days: 2));
    await tester.enterText(
      find.byType(TextField).last,
      '${previous.month}/${previous.day}/${previous.year}',
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    final expected =
        '${previous.year}-${previous.month.toString().padLeft(2, '0')}-${previous.day.toString().padLeft(2, '0')}';
    expect(requests.last, expected);
    expect(find.text('Món ngày trước × 2'), findsOneWidget);
    await tester.tap(find.text('Về hôm nay'));
    await tester.pumpAndSettle();
    expect(requests.last, isNull);
    expect(find.text('Món hôm nay × 2'), findsOneWidget);
  });

  testWidgets(
    'Đang chờ gồm chờ bếp, đang nấu và chờ phục vụ, không gồm món đã ra',
    (tester) async {
      var selected = '';
      final rows = [
        {...item(id: 1, status: 'completed'), 'name': 'Món chờ bưng'},
        {...item(id: 2, status: 'preparing'), 'name': 'Món chờ bếp'},
        {...item(id: 3, status: 'cooking'), 'name': 'Món đang nấu'},
        {...item(id: 4, status: 'served'), 'name': 'Món đã phục vụ'},
      ];
      final client = MockClient((req) async {
        selected = req.url.queryParameters['status'] ?? '';
        final visible = selected == 'pending'
            ? rows.where((row) => row['status'] != 'served').toList()
            : rows;
        return response({
          ...data(rows.first),
          'items': visible,
          'total': visible.length,
          'counts': {'preparing': 1, 'cooking': 1, 'completed': 1, 'served': 1},
        });
      });
      addTearDown(client.close);
      await tester.pumpWidget(
        MaterialApp(
          home: ItemTimingPage(
            api: StaffApi(client: client),
            autoRefresh: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Đang chờ (3)'), findsOneWidget);
      expect(find.text('Tất cả (4)'), findsOneWidget);
      await tester.tap(find.text('Đang chờ (3)'));
      await tester.pumpAndSettle();
      expect(selected, 'pending');
      expect(find.text('Món đã phục vụ × 2'), findsNothing);
      expect(find.text('Món chờ bưng × 2'), findsOneWidget);
      expect(find.text('Món chờ bếp × 2'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Món chờ bưng × 2')).dy,
        lessThan(tester.getTopLeft(find.text('Món chờ bếp × 2')).dy),
      );
      await tester.scrollUntilVisible(
        find.text('Món đang nấu × 2'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Món đang nấu × 2'), findsOneWidget);
    },
  );

  testWidgets(
    'Dòng thu gọn hiện thời gian từ order đến hiện tại, món đã phục vụ giữ tổng thời gian',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var status = 'cooking';
      var elapsed = 480;
      final client = MockClient(
        (_) async => response(
          data({...item(status: status), 'totalElapsedSeconds': elapsed}),
        ),
      );
      addTearDown(client.close);
      await tester.pumpWidget(
        MaterialApp(
          home: ItemTimingPage(
            api: StaffApi(client: client),
            autoRefresh: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Đã chờ: 8 phút 0 giây'), findsOneWidget);
      expect(find.text('Gọi: 10:00:00'), findsOneWidget);
      expect(find.text('Tạo món'), findsNothing);
      elapsed = 600;
      await tester.tap(find.byTooltip('Cập nhật thời gian món'));
      await tester.pumpAndSettle();
      expect(find.text('Đã chờ: 10 phút 0 giây'), findsOneWidget);
      status = 'served';
      elapsed = 9999;
      await tester.tap(find.byTooltip('Cập nhật thời gian món'));
      await tester.pumpAndSettle();
      expect(find.text('Tổng: 8 phút 0 giây'), findsOneWidget);
      expect(find.text('Gọi: 10:00:00'), findsNothing);
      expect(find.textContaining('Đã chờ:'), findsNothing);
      expect(find.text('Tạo món'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  test('Định dạng thời lượng giữ số giây và dữ liệu thiếu', () {
    expect(timingDuration(0), '0 giây');
    expect(timingDuration(61), '1 phút 1 giây');
    expect(timingDuration(270), '4 phút 30 giây');
    expect(timingDuration(3661), '1 giờ 1 phút 1 giây');
    expect(timingDuration(null), 'Chưa đủ mốc');
  });
  testWidgets(
    'Hiển thị đủ bốn mốc và công thức trên màn hình nhỏ, lọc trạng thái',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var selected = '';
      final client = MockClient((req) async {
        expect(req.headers['authorization'], 'Bearer manager-test');
        selected = req.url.queryParameters['status'] ?? '';
        return response(
          data(item(status: selected == 'cooking' ? 'cooking' : 'served')),
        );
      });
      addTearDown(client.close);
      await tester.pumpWidget(
        MaterialApp(
          home: ItemTimingPage(
            api: StaffApi(client: client)..token = 'manager-test',
            autoRefresh: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cơm gà × 2'), findsOneWidget);
      expect(find.text('Tạo món'), findsNothing);
      expect(find.text('Tổng thời gian ra món'), findsNothing);
      await tester.tap(find.text('Cơm gà × 2'));
      await tester.pumpAndSettle();
      for (final label in [
        'Tạo món',
        'Bắt đầu nấu',
        'Nấu xong',
        'Đã bưng ra',
      ]) {
        await tester.scrollUntilVisible(
          find.text(label),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(label), findsOneWidget);
      }
      await tester.scrollUntilVisible(
        find.text('Tổng thời gian ra món'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('8 phút 0 giây'), findsOneWidget);
      expect(find.text('2 phút 0 giây'), findsOneWidget);
      expect(find.text('5 phút 0 giây'), findsOneWidget);
      expect(find.text('1 phút 0 giây'), findsOneWidget);
      expect(find.text('02/11 10:00:00'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Đang nấu (1)'),
        -250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Đang nấu (1)'));
      await tester.pumpAndSettle();
      expect(selected, 'cooking');
      expect(
        find.text('Thời gian ở trạng thái hiện tại: 2 phút 0 giây'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cơm gà × 2'));
      await tester.pumpAndSettle();
      expect(
        find.text('Thời gian ở trạng thái hiện tại: 2 phút 0 giây'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Dữ liệu cũ không hiển thị thời gian giả, phân trang và lỗi tải có thể thử lại',
    (tester) async {
      var offline = false;
      var offset = 0;
      final client = MockClient((req) async {
        offset = int.parse(req.url.queryParameters['offset']!);
        return offline
            ? response({'message': 'Mất kết nối.'}, 503)
            : response(
                data(item(id: offset + 1, missing: true), total: 2, limit: 1),
              );
      });
      addTearDown(client.close);
      await tester.pumpWidget(
        MaterialApp(
          home: ItemTimingPage(
            api: StaffApi(client: client),
            autoRefresh: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Chưa ghi nhận'), findsNothing);
      await tester.tap(find.text('Cơm gà × 2'));
      await tester.pumpAndSettle();
      expect(find.text('Chưa ghi nhận'), findsNWidgets(4));
      expect(find.text('Chưa đủ mốc'), findsNWidgets(4));
      await tester.scrollUntilVisible(
        find.text('Trang sau'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Trang sau'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Trang sau'));
      await tester.pumpAndSettle();
      expect(offset, 1);
      expect(find.byKey(const ValueKey('timing-item-2')), findsOneWidget);
      offline = true;
      await tester.tap(find.byTooltip('Cập nhật thời gian món'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Thử lại'),
        -250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Mất kết nối.'), findsOneWidget);
      offline = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Mất kết nối.'), findsNothing);
    },
  );
  testWidgets('Tìm món bỏ qua kết quả trả về chậm của truy vấn cũ', (
    tester,
  ) async {
    final first = Completer<http.Response>();
    var calls = 0;
    final client = MockClient((req) async {
      if (++calls == 1) return first.future;
      expect(req.url.queryParameters['q'], 'A01');
      return response(data({...item(), 'name': 'Món mới nhất'}));
    });
    addTearDown(client.close);
    await tester.pumpWidget(
      MaterialApp(
        home: ItemTimingPage(api: StaffApi(client: client), autoRefresh: false),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'A01');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    first.complete(response(data(item())));
    await tester.pumpAndSettle();
    expect(find.text('Món mới nhất × 2'), findsOneWidget);
    expect(find.text('Cơm gà × 2'), findsNothing);
  });
}
