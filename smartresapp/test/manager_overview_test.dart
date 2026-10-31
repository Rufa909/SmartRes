import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartresapp/manager_page.dart';
import 'package:smartresapp/staff_api.dart';

import 'fixtures/management_overview.dart';

http.Response response(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
Widget page(http.Client client) => MaterialApp(
  home: ManagerPage(
    api: StaffApi(client: client)..token = 'manager-token',
    autoRefresh: false,
  ),
);

void main() {
  testWidgets(
    'Tổng quan hiện doanh thu, biểu đồ, vận hành và món bán chạy trên màn hình nhỏ',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final client = MockClient((req) async {
        expect(req.url.path, '/api/staff/management/overview');
        expect(req.headers['authorization'], 'Bearer manager-token');
        return response(overviewFixture());
      });
      addTearDown(client.close);
      await tester.pumpWidget(page(client));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('manager-revenue'))).data,
        '500.000 đ',
      );
      expect(
        find.text('100.0% so với kỳ trước', findRichText: true),
        findsNothing,
      ); // Giá trị có ký hiệu ↑.
      await tester.scrollUntilVisible(
        find.text('Vận hành hiện tại'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('3/8 bàn đang dùng · 5 bàn trống'), findsOneWidget);
      expect(find.text('1 bàn chờ thanh toán'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Món bán chạy'),
        350,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byType(RevenueBars), findsOneWidget);
      expect(find.text('Cơm chiên hải sản'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('3110-A01-1000'),
        350,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Tiền mặt · 5 bill'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Đổi bộ lọc không nhận lại kết quả chậm của khoảng ngày cũ', (
    tester,
  ) async {
    final first = Completer<http.Response>();
    var calls = 0;
    final client = MockClient((req) async {
      calls++;
      if (calls == 1) return first.future;
      expect(req.url.queryParameters['from'], req.url.queryParameters['to']);
      return response(overviewFixture(revenue: 200000));
    });
    addTearDown(client.close);
    await tester.pumpWidget(page(client));
    await tester.pump();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Hôm nay'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('manager-revenue'))).data,
      '200.000 đ',
    );
    first.complete(response(overviewFixture(revenue: 900000)));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('manager-revenue'))).data,
      '200.000 đ',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Lỗi tải có thử lại, khoảng trống hiện 0 và biểu đồ không chia cho 0',
    (tester) async {
      var fail = true;
      final empty = overviewFixture(revenue: 0);
      empty['summary'] = {
        'revenue': 0,
        'invoiceCount': 0,
        'averageBill': 0,
        'discountAmount': 0,
        'previousRevenue': 0,
        'changePercent': null,
      };
      final client = MockClient(
        (req) async => fail
            ? response({'message': 'Không tải được báo cáo.'}, 503)
            : response(empty),
      );
      addTearDown(client.close);
      await tester.pumpWidget(page(client));
      await tester.pumpAndSettle();
      expect(find.text('Không tải được báo cáo.'), findsOneWidget);
      expect(find.byKey(const Key('manager-revenue')), findsNothing);
      fail = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('manager-revenue'))).data,
        '0 đ',
      );
      await tester.scrollUntilVisible(
        find.text('Biểu đồ doanh thu'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text('Chưa có doanh thu trong khoảng ngày này.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Đổi ngày mà lỗi thì không gắn số liệu cũ vào khoảng mới', (
    tester,
  ) async {
    var calls = 0;
    final client = MockClient(
      (req) async => ++calls == 1
          ? response(overviewFixture())
          : response({'message': 'Mất kết nối.'}, 503),
    );
    addTearDown(client.close);
    await tester.pumpWidget(page(client));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('manager-revenue')), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Hôm nay'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('manager-revenue')), findsNothing);
    expect(find.text('Mất kết nối.'), findsOneWidget);
  });
}
