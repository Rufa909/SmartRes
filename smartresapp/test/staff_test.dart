import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartresapp/staff_api.dart';
import 'package:smartresapp/staff_page.dart';

void main() {
  testWidgets('Nhận dữ liệu server và xác nhận phục vụ qua API', (
    tester,
  ) async {
    bool served = false;
    final client = MockClient((req) async {
      if (req.method == 'POST') {
        expect(req.url.path, '/api/staff/items/12/serve');
        served = true;
        return http.Response('{"ok":true}', 200);
      }
      return http.Response(
        jsonEncode({
          'tables': [
            {
              'id': 1,
              'code': 'A01',
              'area': 'Tầng 1',
              'seats': 4,
              'guests': 2,
              'status': 'dining',
            },
            {
              'id': 2,
              'code': 'B01',
              'area': 'Tầng 2',
              'seats': 4,
              'guests': 0,
              'status': 'available',
            },
          ],
          'menu': [],
          'items': [
            {
              'id': 12,
              'tableCode': 'A01',
              'name': 'Cơm chiên',
              'quantity': 2,
              'status': served ? 'served' : 'completed',
              'unitPrice': 45000,
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
        home: StaffPage(api: StaffApi(client: client), autoRefresh: false),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Phục vụ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận đã phục vụ'));
    await tester.pumpAndSettle();
    expect(served, true);
    expect(find.text('Xác nhận đã phục vụ'), findsNothing);
    expect(find.textContaining('Đã phục vụ ·'), findsOneWidget);
    await tester.tap(find.text('Sơ đồ bàn').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tầng 2').first);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text('B01'), findsOneWidget);
    expect(find.text('A01'), findsNothing);
  });
  testWidgets('Mất mạng hiển thị lỗi thay vì dữ liệu mẫu', (tester) async {
    final client = MockClient(
      (_) async => throw http.ClientException('offline'),
    );
    addTearDown(client.close);
    await tester.pumpWidget(
      MaterialApp(
        home: StaffPage(api: StaffApi(client: client), autoRefresh: false),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Không kết nối được máy chủ.'), findsOneWidget);
    expect(find.text('A01'), findsNothing);
  });
}
