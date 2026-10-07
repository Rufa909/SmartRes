import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartresapp/staff_api.dart';
import 'package:smartresapp/staff_page.dart';
import 'package:smartresapp/ready_alert.dart';
import 'package:smartresapp/restaurant_theme.dart';

void main() {
  test('Tìm tiếng Việt không dấu, không phân biệt hoa thường', () {
    expect(matchesSearch('Cơm chiên hải sản', 'COM HAI'), true);
    expect(matchesSearch('Trà đào cam sả', 'tra dao'), true);
    expect(matchesSearch('Cơm', 'tra'), false);
  });
  test('Âm báo theo ID mới, không theo số lượng hoặc tải lại', () {
    final tracker = ReadyTracker();
    expect(
      tracker.update([
        {'id': 1, 'status': 'cooking'},
      ]),
      isEmpty,
    );
    expect(
      tracker.update([
        {'id': 1, 'status': 'completed'},
      ]).length,
      1,
    );
    expect(
      tracker.update([
        {'id': 1, 'status': 'completed'},
      ]),
      isEmpty,
    );
    expect(
      tracker.update([
        {'id': 1, 'status': 'served'},
        {'id': 2, 'status': 'completed'},
      ]).length,
      1,
    );
    expect(
      tracker.update([
        {'id': 1, 'status': 'completed'},
        {'id': 2, 'status': 'completed'},
      ]),
      isEmpty,
    );
  });
  testWidgets('Tìm món vẫn giữ giỏ và gửi đúng giá trị qua API', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Map<String, dynamic>? sent;
    final client = MockClient((req) async {
      sent = jsonDecode(req.body) as Map<String, dynamic>;
      return http.Response('{"message":"Lỗi thử nghiệm"}', 503);
    });
    addTearDown(client.close);
    await tester.pumpWidget(
      MaterialApp(
        home: OrderSheet(
          table: const {'id': 1, 'code': 'A01', 'guests': 2},
          menu: const [
            {
              'id': 1,
              'name': 'Cơm chiên hải sản',
              'price': 45000,
              'available': true,
              'category': 'Món chính',
            },
            {
              'id': 5,
              'name': 'Trà đào cam sả',
              'price': 25000,
              'available': true,
              'category': 'Đồ uống',
            },
            {
              'id': 6,
              'name': 'Lẩu hải sản',
              'price': 250000,
              'available': false,
              'category': 'Món chính',
            },
          ],
          api: StaffApi(client: client),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'com chien');
    await tester.pumpAndSettle();
    expect(find.text('Trà đào cam sả'), findsNothing);
    await tester.tap(find.byTooltip('Thêm Cơm chiên hải sản'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'tra dao');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Thêm Trà đào cam sả'));
    await tester.pumpAndSettle();
    expect(find.text('70.000đ'), findsOneWidget);
    await tester.tap(find.text('Đã chọn (2)'));
    await tester.pumpAndSettle();
    expect(find.text('Cơm chiên hải sản'), findsOneWidget);
    await tester.tap(find.text('Gửi món'));
    await tester.pumpAndSettle();
    expect((sent!['items'] as List).length, 2);
    expect(find.textContaining('Giỏ vẫn được giữ'), findsOneWidget);
    expect(find.text('70.000đ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Món hoàn thành gọi âm thanh một lần qua nhiều lần tải', (
    tester,
  ) async {
    int sounds = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      ReadyAlert.channel,
      (call) async {
        if (call.method == 'play') {
          sounds++;
          return true;
        }
        return true;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        ReadyAlert.channel,
        null,
      ),
    );
    String status = 'cooking';
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'tables': [],
          'menu': [],
          'items': [
            {
              'id': 7,
              'name': 'Cơm',
              'tableCode': 'A01',
              'quantity': 1,
              'unitPrice': 45000,
              'status': status,
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    addTearDown(client.close);
    await tester.pumpWidget(
      MaterialApp(
        home: StaffPage(api: StaffApi(client: client), autoRefresh: false),
      ),
    );
    await tester.pumpAndSettle();
    expect(sounds, 0);
    status = 'completed';
    await tester.tap(find.byTooltip('Tải lại dữ liệu'));
    await tester.pumpAndSettle();
    expect(sounds, 1);
    await tester.tap(find.byTooltip('Tải lại dữ liệu'));
    await tester.pumpAndSettle();
    expect(sounds, 1);
  });
}
