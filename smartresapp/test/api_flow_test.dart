import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartresapp/main.dart';
import 'package:smartresapp/restaurant_api.dart';

RestaurantApi fakeApi({bool fail = false}) => RestaurantApi(
  client: MockClient((req) async {
    if (req.method == 'GET') {
      return http.Response(
        jsonEncode({
          'menu': [
            {
              'id': 'com',
              'ten': 'Cơm chiên hải sản',
              'danhMuc': 'Món chính',
              'emoji': '🍚',
              'gia': 45000,
              'conHang': true,
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    final body = jsonDecode(req.body) as Map<String, dynamic>;
    expect(body['items'][0], {'menuItemId': 'com', 'quantity': 1});
    expect(body.containsKey('unitPrice'), false);
    return http.Response(
      jsonEncode(
        fail
            ? {'message': 'Không thể lưu đơn'}
            : {
                'order': {'orderCode': 'SR-TEST', 'totalAmount': 45000},
              },
      ),
      fail ? 500 : 201,
    );
  }),
);

void main() {
  testWidgets('Gửi thành công hiện mã đơn và xóa giỏ', (tester) async {
    final api = fakeApi();
    addTearDown(api.client.close);
    await tester.pumpWidget(MyApp(api: api));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Thêm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xem giỏ hàng'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gửi đơn gọi món'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Đã gửi đơn SR-TEST'), findsOneWidget);
    expect(find.text('Giỏ hàng đang trống'), findsOneWidget);
  });
  testWidgets('Lỗi server giữ giỏ để thử lại', (tester) async {
    final api = fakeApi(fail: true);
    addTearDown(api.client.close);
    await tester.pumpWidget(MyApp(api: api));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Thêm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xem giỏ hàng'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gửi đơn gọi món'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Giỏ vẫn được giữ'), findsOneWidget);
    expect(find.byTooltip('Tăng Cơm chiên hải sản'), findsOneWidget);
  });
}
