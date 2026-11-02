import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartresapp/discount_promotion_hub.dart';
import 'package:smartresapp/staff_api.dart';

http.Response response(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
void main() {
  testWidgets('Ba mục lớn hiện riêng, mở Giảm giá mới gọi danh sách mã', (
    tester,
  ) async {
    var calls = 0;
    final client = MockClient((req) async {
      calls++;
      expect(req.url.path, '/api/staff/management/discounts');
      return response({'discounts': []});
    });
    addTearDown(client.close);
    await tester.pumpWidget(
      MaterialApp(
        home: DiscountPromotionHub(api: StaffApi(client: client)),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.text('Khuyến mãi'), findsOneWidget);
    expect(find.text('Giảm giá'), findsOneWidget);
    expect(find.text('Các đơn đã áp dụng'), findsOneWidget);
    await tester.tap(find.text('Giảm giá'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Giảm giá'), findsOneWidget);
    expect(find.text('Sơ đồ bàn'), findsNothing);
    expect(find.text('Tạo mã giảm giá'), findsOneWidget);
  });
  testWidgets('Các đơn đã áp dụng dùng bộ lọc giảm giá và mở hóa đơn đã lưu', (
    tester,
  ) async {
    final receipt = {
      'historyId': 1,
      'invoiceCode': 'HD-DISCOUNT',
      'tableId': 1,
      'tableCode': 'A01',
      'guests': 2,
      'paidAt': '2026-11-02T05:00:00Z',
      'issuedAt': '2026-11-02T05:00:00Z',
      'paymentStatus': 'paid',
      'paymentMethod': 'cash',
      'discountMode': 'promotion',
      'promotionName': 'Khung giờ trưa',
      'discountAmount': 15000,
      'subtotalAmount': 100000,
      'totalAmount': 85000,
      'items': [
        {
          'id': 1,
          'name': 'Cơm',
          'quantity': 1,
          'unitPrice': 100000,
          'lineTotal': 100000,
          'status': 'served',
        },
      ],
    };
    final client = MockClient((req) async {
      if (req.url.path.endsWith('/history/1')) {
        return response({'invoice': receipt});
      }
      expect(req.url.path, '/api/staff/cashier/history');
      expect(req.url.queryParameters['discounted'], 'true');
      return response({
        'invoices': [receipt],
        'total': 1,
        'offset': 0,
        'limit': 30,
      });
    });
    addTearDown(client.close);
    await tester.pumpWidget(
      MaterialApp(
        home: DiscountPromotionHub(api: StaffApi(client: client)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Các đơn đã áp dụng'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Đã giảm: 15.000 đ'), findsOneWidget);
    await tester.tap(find.text('HD-DISCOUNT • Bàn A01'));
    await tester.pumpAndSettle();
    expect(find.text('In hóa đơn'), findsOneWidget);
    expect(find.text('Xác nhận thanh toán'), findsNothing);
  });
}
