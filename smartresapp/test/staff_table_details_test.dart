import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartresapp/staff_api.dart';
import 'package:smartresapp/staff_table_details.dart';

const table = {
  'id': 1,
  'code': 'A01',
  'area': 'Tầng 1',
  'seats': 4,
  'guests': 2,
  'status': 'dining',
};
Widget details(StaffApi api) => MaterialApp(
  home: Scaffold(
    body: SafeArea(
      child: StaffTableDetails(
        api: api,
        table: table,
        autoRefresh: false,
        onSeat: (_) {},
        onOrder: (_) {},
        onPayment: (_) {},
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'Hiển thị món, số lượng, giá, ghi chú và trạng thái; tải lại khi đã thanh toán',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var paid = false;
      final client = MockClient((req) async {
        expect(req.url.path, '/api/staff/tables/1/details');
        return http.Response(
          jsonEncode({
            'table': {
              ...table,
              'status': paid ? 'available' : 'dining',
              'guests': paid ? 0 : 2,
            },
            'items': paid
                ? []
                : [
                    {
                      'id': 1,
                      'name': 'Cơm chiên',
                      'quantity': 2,
                      'unitPrice': 45000,
                      'lineTotal': 90000,
                      'status': 'cooking',
                      'note': 'Ít cay',
                      'orderCode': 'SR-1',
                    },
                    {
                      'id': 2,
                      'name': 'Trà đào',
                      'quantity': 1,
                      'unitPrice': 25000,
                      'lineTotal': 25000,
                      'status': 'served',
                      'note': null,
                      'orderCode': 'SR-2',
                    },
                  ],
            'subtotalAmount': paid ? 0 : 115000,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      addTearDown(client.close);
      await tester.pumpWidget(details(StaffApi(client: client)));
      await tester.pumpAndSettle();
      expect(find.text('Cơm chiên'), findsOneWidget);
      expect(find.text('Trà đào'), findsOneWidget);
      expect(find.text('2 × 45.000 đ'), findsOneWidget);
      expect(find.text('115.000 đ'), findsOneWidget);
      expect(find.text('Đang nấu'), findsOneWidget);
      expect(find.text('Đã phục vụ'), findsOneWidget);
      expect(find.text('Ghi chú: Ít cay'), findsOneWidget);
      paid = true;
      await tester.tap(find.byTooltip('Tải lại chi tiết bàn'));
      await tester.pumpAndSettle();
      expect(find.text('Cơm chiên'), findsNothing);
      expect(find.text('Bàn trống, chưa có món đã gọi.'), findsOneWidget);
      expect(find.text('Nhận bàn'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Lỗi API có thể thử lại; danh sách dài cuộn được và không tràn', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var fail = true;
    final client = MockClient((req) async {
      if (fail) {
        return http.Response(
          jsonEncode({'message': 'Không tải được món.'}),
          503,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response(
        jsonEncode({
          'table': {...table, 'status': 'waiting_payment'},
          'items': List.generate(
            25,
            (i) => {
              'name': 'Món số $i',
              'quantity': 1,
              'unitPrice': 10000,
              'lineTotal': 10000,
              'status': 'preparing',
            },
          ),
          'subtotalAmount': 250000,
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    addTearDown(client.close);
    await tester.pumpWidget(details(StaffApi(client: client)));
    await tester.pumpAndSettle();
    expect(find.text('Không tải được món.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Gọi thêm món'),
          )
          .onPressed,
      isNull,
    );
    fail = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Món số 24'),
      500,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Món số 24'), findsOneWidget);
    expect(find.text('Bàn đang chờ thu ngân thanh toán.'), findsOneWidget);
    expect(find.text('250.000 đ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
