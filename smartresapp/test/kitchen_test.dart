import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartresapp/kitchen_page.dart';
import 'package:smartresapp/staff_api.dart';

void main() {
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
