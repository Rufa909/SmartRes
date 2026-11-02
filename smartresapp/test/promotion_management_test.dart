import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartresapp/promotion_management_page.dart';
import 'package:smartresapp/staff_api.dart';

http.Response response(Object value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
void main() {
  testWidgets('Chọn khoảng ngày và nhập giờ bắt đầu, kết thúc được lưu đúng', (
    tester,
  ) async {
    Map<String, dynamic>? saved;
    final client = MockClient((req) async {
      if (req.method == 'POST') {
        saved = jsonDecode(req.body) as Map<String, dynamic>;
        return response({
          'promotion': {...saved!, 'id': 1, 'version': 1},
        });
      }
      return response({
        'promotions': saved == null
            ? []
            : [
                {...saved!, 'id': 1, 'version': 1},
              ],
      });
    });
    addTearDown(client.close);
    await tester.pumpWidget(
      MaterialApp(
        home: PromotionManagementPage(api: StaffApi(client: client)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm chương trình'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('promo-name')),
      'Khung giờ chiều',
    );
    await tester.enterText(find.byKey(const Key('promo-value')), '10');
    await tester.ensureVisible(find.byKey(const Key('promo-dates')));
    await tester.tap(find.byKey(const Key('promo-dates')));
    await tester.pumpAndSettle();
    expect(find.text('Chọn khoảng ngày khuyến mãi'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    final dateFields = find.descendant(
      of: find.byType(DateRangePickerDialog),
      matching: find.byType(TextField),
    );
    expect(dateFields, findsNWidgets(2));
    final from = DateTime.now().subtract(const Duration(days: 1));
    final to = from.add(const Duration(days: 5));
    await tester.enterText(
      dateFields.at(0),
      '${from.month}/${from.day}/${from.year}',
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      dateFields.at(1),
      '${to.month}/${to.day}/${to.year}',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Áp dụng'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('promo-start')));
    await tester.tap(find.byKey(const Key('promo-start')));
    await tester.pumpAndSettle();
    expect(find.text('Chọn giờ bắt đầu'), findsOneWidget);
    final timeFields = find.descendant(
      of: find.byType(TimePickerDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(timeFields.at(0), '15');
    await tester.enterText(timeFields.at(1), '30');
    await tester.tap(find.text('Chọn'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('promo-end')));
    await tester.tap(find.byKey(const Key('promo-end')));
    await tester.pumpAndSettle();
    await tester.enterText(timeFields.at(0), '18');
    await tester.enterText(timeFields.at(1), '45');
    await tester.tap(find.text('Chọn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu chương trình'));
    await tester.pumpAndSettle();
    String iso(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    expect(saved!['startDate'], iso(from));
    expect(saved!['endDate'], iso(to));
    expect(saved!['startTime'], '15:30');
    expect(saved!['endTime'], '18:45');
    expect(saved!['isAlwaysActive'], false);
    expect(saved!['allDay'], false);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Quản lý tạo 24/7, bật tắt và sửa thành khung giờ theo thứ/ngày trên màn hình nhỏ',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final promotions = <Map<String, dynamic>>[];
      var saves = 0, toggles = 0;
      final client = MockClient((req) async {
        expect(req.headers['authorization'], 'Bearer manager-test');
        if (req.method == 'GET') return response({'promotions': promotions});
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        if (req.url.path.endsWith('/status')) {
          toggles++;
          expect(body, {'version': 1, 'isActive': false});
          promotions[0] = {...promotions[0], 'isActive': false, 'version': 2};
          return response({'ok': true});
        }
        saves++;
        expect(body['discountValue'], 20);
        expect(body['maxDiscountAmount'], 30000);
        expect(body['minBillAmount'], 100000);
        if (saves == 1) {
          expect(body['isAlwaysActive'], true);
          expect(body['startDate'], isNull);
          promotions.add({...body, 'id': 1, 'version': 1});
        } else {
          expect(body['version'], 2);
          expect(body['isAlwaysActive'], false);
          expect(body['isActive'], false);
          expect(body['allDay'], false);
          expect(body['startTime'], '14:00');
          expect(body['endTime'], '17:00');
          expect(body['weekdays'], [1, 2, 3, 4, 5, 6]);
          expect(body['startDate'], isNotNull);
          expect(body['endDate'], isNotNull);
          promotions[0] = {...body, 'id': 1, 'version': 3};
        }
        return response({'promotion': promotions[0]});
      });
      addTearDown(client.close);
      await tester.pumpWidget(
        MaterialApp(
          home: PromotionManagementPage(
            api: StaffApi(client: client)..token = 'manager-test',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thêm chương trình'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('promo-name')), 'Giờ trưa');
      await tester.enterText(find.byKey(const Key('promo-value')), '20');
      await tester.ensureVisible(find.byKey(const Key('promo-cap')));
      await tester.enterText(find.byKey(const Key('promo-cap')), '30000');
      await tester.ensureVisible(find.byKey(const Key('promo-minimum')));
      await tester.enterText(find.byKey(const Key('promo-minimum')), '100000');
      await tester.ensureVisible(find.byKey(const Key('promo-always')));
      await tester.tap(find.byKey(const Key('promo-always')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu chương trình'));
      await tester.pumpAndSettle();
      expect(find.text('Giờ trưa'), findsOneWidget);
      expect(find.text('Liên tục 24/7 đến khi tắt'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('promotion-switch-1')));
      await tester.pumpAndSettle();
      expect(toggles, 1);
      expect(find.textContaining('Tạm dừng'), findsOneWidget);
      await tester.tap(find.text('Sửa chương trình'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('promo-always')));
      await tester.tap(find.byKey(const Key('promo-always')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('promo-all-day')));
      await tester.tap(find.byKey(const Key('promo-all-day')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(FilterChip, 'CN'));
      await tester.tap(find.widgetWithText(FilterChip, 'CN'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu chương trình'));
      await tester.pumpAndSettle();
      expect(saves, 2);
      expect(find.textContaining('14:00–17:00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
