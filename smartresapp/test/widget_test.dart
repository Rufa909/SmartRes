import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartresapp/main.dart';

import 'api_flow_test.dart' show fakeApi;

void main() {
  testWidgets('Thêm món và giảm về giỏ trống', (tester) async {
    final api = fakeApi();
    addTearDown(api.client.close);
    await tester.pumpWidget(MyApp(api: api));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Thêm').first);
    await tester.pumpAndSettle();
    expect(find.text('1 món • 45.000 đ'), findsOneWidget);
    await tester.tap(find.text('Xem giỏ hàng'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tăng Cơm chiên hải sản'));
    await tester.pumpAndSettle();
    expect(find.text('90.000 đ'), findsNWidgets(2));
    await tester.tap(find.byTooltip('Giảm Cơm chiên hải sản'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Giảm Cơm chiên hải sản'));
    await tester.pumpAndSettle();
    expect(find.text('Giỏ hàng đang trống'), findsOneWidget);
  });
}
