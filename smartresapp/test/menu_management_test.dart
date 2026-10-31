import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartresapp/staff_api.dart';
import 'package:smartresapp/menu_management_page.dart';
import 'package:smartresapp/manager_page.dart';

import 'fixtures/management_overview.dart';

const categories = [
  {'id': 1, 'name': 'Món chính', 'sortOrder': 0, 'version': 1},
];
Map<String, dynamic> dish({bool available = true, int version = 1}) => {
  'id': 1,
  'name': 'Cơm chiên hải sản',
  'categoryId': 1,
  'price': 45000,
  'description': 'Cơm nóng',
  'emoji': '🍚',
  'imageUrl': '',
  'available': available,
  'version': version,
};
http.Response jsonResponse(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
Future<void> enter(WidgetTester tester, String label, String value) async {
  final field = find.widgetWithText(TextFormField, label);
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
}

Future<void> save(WidgetTester tester, String label) async {
  final button = find.widgetWithText(FilledButton, label);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Quản lý mở thực đơn, tìm không dấu và tắt bán với version đúng',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var available = true;
      Map<String, dynamic>? sent;
      final client = MockClient((req) async {
        expect(req.headers['authorization'], 'Bearer manager-token');
        if (req.url.path.endsWith('/overview')) {
          return jsonResponse(overviewFixture());
        }
        if (req.method == 'POST') {
          expect(req.url.path, '/api/staff/management/menu/1/availability');
          sent = jsonDecode(req.body) as Map<String, dynamic>;
          available = sent!['available'] as bool;
          return jsonResponse({'item': dish(available: available, version: 2)});
        }
        return jsonResponse({
          'items': [dish(available: available)],
          'categories': categories,
        });
      });
      addTearDown(client.close);
      final api = StaffApi(client: client)..token = 'manager-token';
      await tester.pumpWidget(
        MaterialApp(home: ManagerPage(api: api, autoRefresh: false)),
      );
      await tester.tap(find.text('Thực đơn'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'com hai');
      await tester.pumpAndSettle();
      expect(find.text('Cơm chiên hải sản'), findsOneWidget);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(sent, {'version': 1, 'available': false});
      expect(tester.widget<Switch>(find.byType(Switch)).value, false);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Còn bán'));
      await tester.pumpAndSettle();
      expect(find.text('Cơm chiên hải sản'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Form thêm món kiểm tra giá, gửi đủ dữ liệu và giữ nội dung khi server lỗi',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var calls = 0;
      Map<String, dynamic>? sent;
      final client = MockClient((req) async {
        calls++;
        sent = jsonDecode(req.body) as Map<String, dynamic>;
        return jsonResponse({'message': 'Tên món đã tồn tại.'}, 409);
      });
      addTearDown(client.close);
      await tester.pumpWidget(
        MaterialApp(
          home: MenuItemEditor(
            api: StaffApi(client: client),
            categories: categories,
          ),
        ),
      );
      await enter(tester, 'Tên món', 'Cá kho');
      await enter(tester, 'Giá bán (đồng)', '-10');
      await save(tester, 'Lưu món');
      expect(calls, 0);
      await enter(tester, 'Giá bán (đồng)', '89000');
      await enter(tester, 'Mô tả', 'Ít cay');
      await save(tester, 'Lưu món');
      expect(calls, 1);
      expect(sent!['name'], 'Cá kho');
      expect(sent!['price'], 89000);
      expect(sent!['categoryId'], 1);
      expect(sent!['available'], true);
      expect(sent!['description'], 'Ít cay');
      expect(sent!.containsKey('version'), false);
      expect(find.text('Tên món đã tồn tại.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Sửa món gửi version; form danh mục kiểm tra và gửi đúng thứ tự',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Map<String, dynamic>? sent;
      String? path;
      final client = MockClient((req) async {
        path = req.url.path;
        sent = jsonDecode(req.body) as Map<String, dynamic>;
        return jsonResponse({'message': 'Dữ liệu đã thay đổi.'}, 409);
      });
      addTearDown(client.close);
      final api = StaffApi(client: client);
      await tester.pumpWidget(
        MaterialApp(
          home: MenuItemEditor(
            api: api,
            categories: categories,
            item: dish(version: 7),
          ),
        ),
      );
      await enter(tester, 'Giá bán (đồng)', '55000');
      await save(tester, 'Lưu món');
      expect(path, '/api/staff/management/menu/1');
      expect(sent!['version'], 7);
      await tester.pumpWidget(
        MaterialApp(
          home: CategoryEditor(api: api, category: categories.first),
        ),
      );
      await tester.pumpAndSettle();
      await enter(tester, 'Tên danh mục', 'Đặc sản');
      await enter(tester, 'Thứ tự hiển thị', '3');
      await save(tester, 'Lưu danh mục');
      expect(path, '/api/staff/management/categories/1');
      expect(sent, {'name': 'Đặc sản', 'sortOrder': 3, 'version': 1});
      expect(find.text('Dữ liệu đã thay đổi.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Lỗi tải thực đơn có thử lại, không hiển thị dữ liệu giả', (
    tester,
  ) async {
    var fail = true;
    final client = MockClient(
      (req) async => fail
          ? jsonResponse({'message': 'Không có quyền.'}, 403)
          : jsonResponse({
              'items': [dish()],
              'categories': categories,
            }),
    );
    addTearDown(client.close);
    await tester.pumpWidget(
      MaterialApp(
        home: MenuManagementPage(api: StaffApi(client: client)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Không có quyền.'), findsOneWidget);
    expect(find.text('Cơm chiên hải sản'), findsNothing);
    fail = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Cơm chiên hải sản'), findsOneWidget);
  });
}
