import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartresapp/staff_page.dart';

void main() {
  testWidgets('Nhân viên xác nhận phục vụ và lọc tầng', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: StaffPage()));
    await tester.tap(find.text('Phục vụ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận đã phục vụ').first);
    await tester.pumpAndSettle();
    expect(find.text('Cơm chiên hải sản'), findsNothing);
    expect(find.text('Gỏi cuốn tôm'), findsOneWidget);
    await tester.tap(find.text('Sơ đồ bàn').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tầng 2').first);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text('B01'), findsOneWidget);
    expect(find.text('A01'), findsNothing);
  });
}
