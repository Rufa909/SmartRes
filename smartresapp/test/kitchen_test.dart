import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartresapp/ready_alert.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartresapp/kitchen_page.dart';
import 'package:smartresapp/staff_api.dart';

void main() {
  testWidgets(
    'Bếp báo món mới một lần, kể cả ngoài bộ lọc và thay món cùng số lượng',
    (tester) async {
      var sounds = 0;
      var offline = false;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        ReadyAlert.channel,
        (call) async {
          if (call.method == 'play') sounds++;
          return true;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          ReadyAlert.channel,
          null,
        ),
      );
      Map<String, dynamic> dish(int id, String status, String table) => {
        'id': id,
        'name': 'Món $id',
        'tableCode': table,
        'quantity': 1,
        'status': status,
        'orderCode': 'SR-$id',
        'createdAt': '2026-10-28T12:00:00Z',
      };
      var items = [dish(1, 'cooking', 'A01')];
      final client = MockClient(
        (_) async => offline
            ? http.Response('{"message":"Offline"}', 503)
            : http.Response(
                jsonEncode({'items': items}),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              ),
      );
      addTearDown(client.close);
      await tester.pumpWidget(
        MaterialApp(
          home: KitchenPage(api: StaffApi(client: client), autoRefresh: false),
        ),
      );
      await tester.pumpAndSettle();
      expect(sounds, 0);
      await tester.tap(find.text('Đang nấu (1)'));
      await tester.pumpAndSettle();
      items = [dish(1, 'cooking', 'A01'), dish(2, 'preparing', 'B02')];
      await tester.tap(find.byTooltip('Tải lại bếp'));
      await tester.pumpAndSettle();
      expect(sounds, 1);
      await tester.tap(find.byTooltip('Tải lại bếp'));
      await tester.pumpAndSettle();
      expect(sounds, 1);
      items = [dish(1, 'cooking', 'A01'), dish(3, 'preparing', 'B02')];
      offline = true;
      await tester.tap(find.byTooltip('Tải lại bếp'));
      await tester.pumpAndSettle();
      expect(sounds, 1);
      offline = false;
      await tester.tap(find.byTooltip('Tải lại bếp'));
      await tester.pumpAndSettle();
      expect(sounds, 2);
      items = [dish(1, 'cooking', 'A01'), dish(3, 'cooking', 'B02')];
      await tester.tap(find.byTooltip('Tải lại bếp'));
      await tester.pumpAndSettle();
      expect(sounds, 2);
    },
  );

  testWidgets('Lọc bàn, đếm phần và khóa thao tác khi mất kết nối', (
    tester,
  ) async {
    bool offline = false;
    final client = MockClient((req) async {
      if (offline) return http.Response('{"message":"Mất kết nối"}', 503);
      return http.Response(
        jsonEncode({
          'items': [
            {
              'id': 1,
              'tableCode': 'A01',
              'name': 'Cơm',
              'quantity': 2,
              'status': 'preparing',
              'orderCode': 'ONE',
              'createdAt': '2026-10-07T00:00:00Z',
            },
            {
              'id': 2,
              'tableCode': 'B01',
              'name': 'Trà',
              'quantity': 3,
              'status': 'preparing',
              'orderCode': 'TWO',
              'createdAt': '2026-10-07T00:01:00Z',
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    addTearDown(client.close);
    await tester.pumpWidget(
      MaterialApp(
        home: KitchenPage(api: StaffApi(client: client), autoRefresh: false),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('5 phần · 2 dòng món'), findsOneWidget);
    await tester.tap(find.text('Tất cả bàn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lọc bàn A01').last);
    await tester.pumpAndSettle();
    expect(find.text('2 phần · 1 dòng món'), findsOneWidget);
    expect(find.text('3 × Trà'), findsNothing);
    offline = true;
    await tester.tap(find.byTooltip('Tải lại bếp'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Bắt đầu nấu'),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('2 × Cơm'), findsOneWidget);
    offline = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Bắt đầu nấu'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('Lần tải đầu thất bại không báo hàng đợi trống', (tester) async {
    final client = MockClient(
      (_) async => http.Response('{"message":"Offline"}', 503),
    );
    addTearDown(client.close);
    await tester.pumpWidget(
      MaterialApp(
        home: KitchenPage(api: StaffApi(client: client), autoRefresh: false),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chưa xác nhận được danh sách món'), findsOneWidget);
    expect(find.text('Chưa có món chờ bếp'), findsNothing);
  });

  testWidgets('Bếp bắt đầu nấu rồi hoàn thành qua API', (tester) async {
    String status = 'preparing';
    final client = MockClient((req) async {
      if (req.method == 'POST') {
        expect(req.url.path, '/api/staff/items/10/kitchen');
        status =
            (jsonDecode(req.body) as Map<String, dynamic>)['status'] as String;
        return http.Response('{"ok":true}', 200);
      }
      return http.Response(
        jsonEncode({
          'items': [
            {
              'id': 10,
              'tableCode': 'A01',
              'name': 'Cơm chiên',
              'quantity': 2,
              'status': status,
              'orderCode': 'SR-TEST',
              'createdAt': DateTime.now().toUtc().toIso8601String(),
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    addTearDown(client.close);
    await tester.pumpWidget(
      MaterialApp(
        home: KitchenPage(api: StaffApi(client: client), autoRefresh: false),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bắt đầu nấu'));
    await tester.pumpAndSettle();
    expect(status, 'cooking');
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đang nấu (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hoàn thành món'));
    await tester.pumpAndSettle();
    expect(status, 'completed');
    await tester.tap(find.text('Chờ phục vụ (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Đã báo nhân viên · Chờ mang ra bàn'), findsOneWidget);
    expect(find.text('Hoàn thành món'), findsNothing);
  });

  testWidgets('Bếp không báo hoàn thành khi server lỗi', (tester) async {
    final client = MockClient((req) async {
      if (req.method == 'POST') {
        return http.Response('{"message":"Server error"}', 503);
      }
      return http.Response(
        jsonEncode({
          'items': [
            {
              'id': 10,
              'tableCode': 'A01',
              'name': 'Cơm',
              'quantity': 1,
              'status': 'cooking',
              'orderCode': 'SR-TEST',
              'createdAt': '2026-10-01T00:00:00Z',
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    addTearDown(client.close);
    await tester.pumpWidget(
      MaterialApp(
        home: KitchenPage(api: StaffApi(client: client), autoRefresh: false),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đang nấu (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hoàn thành món'));
    await tester.pumpAndSettle();
    expect(find.text('Hoàn thành món'), findsOneWidget);
    expect(find.text('Chờ phục vụ (0)'), findsOneWidget);
    expect(find.text('Server error'), findsOneWidget);
  });
}
