import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartresapp/cashier_page.dart';
import 'package:smartresapp/staff_api.dart';

void main() {
  testWidgets('Thu ngân chọn phương thức và thanh toán hóa đơn', (tester) async {
    var paid = false;
    final client = MockClient((req) async {
      if (req.method == 'POST') {
        expect(req.url.path, '/api/staff/tables/2/pay');
        expect((jsonDecode(req.body) as Map<String, dynamic>)['paymentMethod'], 'cash');
        paid = true;
        return http.Response('{"ok":true}', 200);
      }
      final body = paid
          ? {'tables': <Map<String, dynamic>>[]}
          : {
              'tables': [
                {
                  'tableId': 2,
                  'tableCode': 'A02',
                  'guests': 3,
                  'totalAmount': 180000,
                  'orderCount': 2,
                  'pendingItems': 0,
                },
              ],
            };
      return http.Response(jsonEncode(body), 200,
          headers: {'content-type': 'application/json'});
    });
    addTearDown(client.close);
    await tester.pumpWidget(MaterialApp(
      home: CashierPage(api: StaffApi(client: client), autoRefresh: false),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Bàn A02'), findsOneWidget);
    await tester.tap(find.text('Thanh toán'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(paid, isTrue);
    expect(find.text('Chưa có hóa đơn chờ thanh toán'), findsOneWidget);
  });

  testWidgets('Khóa thanh toán khi còn món chưa phục vụ', (tester) async {
    final client = MockClient((_) async => http.Response(jsonEncode({
          'tables': [
            {
              'tableId': 3,
              'tableCode': 'B01',
              'guests': 2,
              'totalAmount': 90000,
              'orderCount': 1,
              'pendingItems': 1,
            },
          ],
        }), 200, headers: {'content-type': 'application/json'}));
    addTearDown(client.close);
    await tester.pumpWidget(MaterialApp(
      home: CashierPage(api: StaffApi(client: client), autoRefresh: false),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Chờ phục vụ món'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Chờ phục vụ món')).onPressed,
      isNull,
    );
  });
}
