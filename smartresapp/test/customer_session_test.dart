import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartresapp/ready_alert.dart';
import 'package:smartresapp/staff_api.dart';
import 'package:smartresapp/staff_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ReadyAlert.channel, (_) async => true),
  );
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ReadyAlert.channel, null),
  );

  testWidgets(
    'Chi tiết bàn chỉ có thao tác phục vụ, không yêu cầu cấp mã cho khách',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/details')) {
          return http.Response(
            jsonEncode({
              'table': {
                'id': 1,
                'code': 'A01',
                'area': 'Tầng 1',
                'seats': 4,
                'guests': 2,
                'status': 'dining',
              },
              'items': [],
              'subtotalAmount': 0,
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        expect(req.url.path, '/api/staff/snapshot');
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
            ],
            'menu': [],
            'items': [],
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
      await tester.tap(find.text('A01'));
      await tester.pumpAndSettle();
      expect(find.text('Gọi thêm món'), findsOneWidget);
      expect(find.text('Yêu cầu thanh toán'), findsOneWidget);
      expect(find.text('Mã gọi món cho khách'), findsNothing);
      expect(find.text('Cấp mã mới'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
