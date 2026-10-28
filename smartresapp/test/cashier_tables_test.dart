import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartresapp/cashier_page.dart';
import 'package:smartresapp/staff_api.dart';
import 'package:smartresapp/table_status.dart';
import 'package:smartresapp/ready_alert.dart';

void main() {
  testWidgets(
    'Yêu cầu mới hiện thông báo, chuông mở đúng bàn và hết thông báo sau thanh toán',
    (tester) async {
      var waiting = false;
      var settled = false;
      var sounds = 0;
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
      int? selectedTable;
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/invoice')) {
          selectedTable = int.parse(req.url.pathSegments[3]);
          return http.Response(
            jsonEncode({'message': 'Kiểm tra mở đúng bàn'}),
            503,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(
          jsonEncode({
            'tables': [
              for (var i = 1; i <= 2; i++)
                {
                  'tableId': i,
                  'tableCode': 'B0$i',
                  'area': 'Tầng $i',
                  'seats': 4,
                  'guests': settled ? 0 : 2,
                  'status': settled
                      ? 'available'
                      : waiting
                      ? 'waiting_payment'
                      : 'dining',
                  'hasInvoice': !settled,
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
          home: CashierPage(api: StaffApi(client: client), autoRefresh: false),
        ),
      );
      await tester.pumpAndSettle();
      expect(sounds, 0);
      expect(find.text('Xem yêu cầu'), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Tầng 1'));
      await tester.pumpAndSettle();
      waiting = true;
      await tester.tap(find.byTooltip('Tải lại sơ đồ bàn'));
      await tester.pumpAndSettle();
      expect(find.text('2 bàn yêu cầu thanh toán: B01, B02'), findsOneWidget);
      expect(find.text('Bàn B01, B02 yêu cầu thanh toán.'), findsOneWidget);
      expect(sounds, 1);
      expect(find.text('B02'), findsNothing);
      await tester.tap(find.byTooltip('Yêu cầu thanh toán'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bàn B02'));
      await tester.pumpAndSettle();
      expect(selectedTable, 2);
      expect(find.text('Kiểm tra mở đúng bàn'), findsOneWidget);
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Tải lại sơ đồ bàn'));
      await tester.pumpAndSettle();
      expect(find.text('Bàn B01, B02 yêu cầu thanh toán.'), findsNothing);
      expect(sounds, 1);
      settled = true;
      await tester.tap(find.byTooltip('Tải lại sơ đồ bàn'));
      await tester.pumpAndSettle();
      expect(find.text('Xem yêu cầu'), findsNothing);
      expect(sounds, 1);
      settled = false;
      await tester.tap(find.byTooltip('Tải lại sơ đồ bàn'));
      await tester.pumpAndSettle();
      expect(sounds, 2);
    },
  );

  testWidgets(
    'Sơ đồ có đủ trạng thái, màu chung với nhân viên và chỉ tải hóa đơn khi chọn bàn',
    (tester) async {
      var invoiceRequests = 0;
      final tables = [
        for (final (i, status) in [
          'available',
          'dining',
          'waiting_payment',
        ].indexed)
          {
            'tableId': i + 1,
            'tableCode': 'A0${i + 1}',
            'area': i == 2 ? 'Tầng 2' : 'Tầng 1',
            'seats': 4,
            'guests': i == 0 ? 0 : 2,
            'status': status,
            'hasInvoice': i == 2,
          },
      ];
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/invoice')) invoiceRequests++;
        return http.Response(
          jsonEncode({'tables': tables}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      addTearDown(client.close);
      await tester.pumpWidget(
        MaterialApp(
          home: CashierPage(api: StaffApi(client: client), autoRefresh: false),
        ),
      );
      await tester.pumpAndSettle();
      expect(invoiceRequests, 0);
      expect(find.text('Sơ đồ bàn'), findsOneWidget);
      for (final status in ['available', 'dining', 'waiting_payment']) {
        final label = tester.widget<Text>(find.text(tableStatus(status)));
        expect(label.style!.color, tableStatusColor(status));
      }
      await tester.tap(find.byKey(const ValueKey('cashier-table-1')));
      await tester.pumpAndSettle();
      expect(
        find.text('Bàn đang trống, chưa có hóa đơn thanh toán.'),
        findsOneWidget,
      );
      expect(find.text('Xác nhận thanh toán'), findsNothing);
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('cashier-table-2')));
      await tester.pumpAndSettle();
      expect(
        find.text('Bàn chưa có món gọi, chưa có hóa đơn thanh toán.'),
        findsOneWidget,
      );
      expect(invoiceRequests, 0);
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Tầng 2'));
      await tester.pumpAndSettle();
      expect(find.text('A01'), findsNothing);
      expect(find.text('A03'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'A01');
      await tester.pumpAndSettle();
      expect(find.text('Không tìm thấy bàn phù hợp.'), findsOneWidget);
    },
  );
}
