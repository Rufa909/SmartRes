import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartresapp/discount_management_page.dart';
import 'package:smartresapp/invoice_dialog.dart';
import 'package:smartresapp/staff_api.dart';

http.Response response(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
void main() {
  testWidgets(
    'Tạo mã tiếng Việt tự động, sửa thành mã thủ công và giữ cấu hình ngày giờ',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Map<String, dynamic>? saved;
      final client = MockClient((req) async {
        if (req.method == 'POST') {
          saved = jsonDecode(req.body) as Map<String, dynamic>;
          return response({'discount': saved});
        }
        return response({
          'discounts': saved == null
              ? []
              : [
                  {
                    ...saved!,
                    'id': 1,
                    'version': 1,
                    'usedQuantity': 0,
                    'remainingQuantity': 100,
                    'discountCode': saved!['discountCode'] ?? 'TAKH10020',
                  },
                ],
        });
      });
      addTearDown(client.close);
      await tester.pumpWidget(
        MaterialApp(
          home: DiscountManagementPage(api: StaffApi(client: client)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tạo mã giảm giá'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('promo-name')),
        'Tri Ân Khách Hàng',
      );
      await tester.ensureVisible(find.byKey(const Key('promo-value')));
      await tester.enterText(find.byKey(const Key('promo-value')), '20.00');
      await tester.ensureVisible(find.byKey(const Key('discount-preview')));
      await tester.pumpAndSettle();
      expect(find.text('Mã dự kiến: TAKH10020'), findsOneWidget);
      await tester.tap(find.text('Lưu mã giảm giá'));
      await tester.pumpAndSettle();
      expect(saved!['codeMode'], 'auto');
      expect(saved!['totalQuantity'], 100);
      expect(saved!['discountName'], 'Tri Ân Khách Hàng');
      expect(saved!['discountPercent'], 20);
      expect(saved!['isAlwaysActive'], false);
      expect(saved!['startDate'], isNotNull);
      expect(saved!['endDate'], isNotNull);
      expect(saved!['weekdays'], hasLength(7));
      expect(saved!.containsKey('usedQuantity'), false);
      expect(saved!.containsKey('discountValue'), false);
      await tester.tap(find.text('Sửa mã giảm giá'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Tự nhập mã'));
      await tester.tap(find.text('Tự nhập mã'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(TextFormField, 'Mã giảm giá'),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mã giảm giá'),
        'khach-vip',
      );
      await tester.tap(find.text('Lưu mã giảm giá'));
      await tester.pumpAndSettle();
      expect(saved!['codeMode'], 'manual');
      expect(saved!['discountCode'], 'KHACH-VIP');
      expect(saved!['version'], 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Thu ngân tra cứu lỗi rõ ràng, xem thẻ hợp lệ rồi mới áp dụng', (
    tester,
  ) async {
    var current = <String, dynamic>{
      'invoiceCode': 'HD1',
      'tableId': 1,
      'tableCode': 'A01',
      'guests': 2,
      'subtotalAmount': 200000,
      'totalAmount': 200000,
      'paymentStatus': 'unpaid',
      'paymentMethod': null,
      'version': 'a' * 64,
      'pendingItems': 0,
      'orderCodes': ['O1'],
      'items': [
        {
          'id': 1,
          'name': 'Cơm',
          'quantity': 2,
          'unitPrice': 100000,
          'lineTotal': 200000,
          'status': 'served',
        },
      ],
    };
    var searches = 0, applies = 0, payments = 0;
    final client = MockClient((req) async {
      if (req.url.path.endsWith('/search')) {
        searches++;
        expect(
          jsonDecode(req.body)['discountCode'],
          searches == 1 ? 'BAD' : 'TAKH10020',
        );
        if (searches == 1) return response({'message': 'Mã đã hết lượt.'}, 409);
        return response({
          'discount': {
            'kind': 'discount_code',
            'discountName': 'Tri Ân Khách Hàng',
            'discountCode': 'TAKH10020',
            'discountType': 'percentage',
            'discountPercent': 20,
            'discountAmount': 30000,
            'remainingQuantity': 7,
          },
        });
      }
      if (req.url.path.endsWith('/discount')) {
        applies++;
        final body = jsonDecode(req.body);
        expect(body['mode'], 'discount_code');
        expect(body['code'], 'TAKH10020');
        current = {
          ...current,
          'discountMode': 'discount_code',
          'discountCode': 'TAKH10020',
          'discountName': 'Tri Ân Khách Hàng',
          'discountAmount': 30000,
          'discountPercentage': 20,
          'totalAmount': 170000,
        };
      }
      if (req.url.path.endsWith('/pay')) payments++;
      return response({'invoice': current});
    });
    addTearDown(client.close);
    await tester.pumpWidget(
      MaterialApp(
        home: InvoiceDialog(
          api: StaffApi(client: client),
          tableId: 1,
          onPaid: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('toggle-discount')));
    await tester.tap(find.byKey(const Key('toggle-discount')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Mã giảm giá'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Mã giảm giá'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.widgetWithText(TextField, 'Nhập mã giảm giá'),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Nhập mã giảm giá'),
      'BAD',
    );
    await tester.ensureVisible(find.text('Tìm kiếm'));
    await tester.tap(find.text('Tìm kiếm'));
    await tester.pumpAndSettle();
    expect(find.text('Mã đã hết lượt.'), findsOneWidget);
    expect(applies, 0);
    await tester.ensureVisible(
      find.widgetWithText(TextField, 'Nhập mã giảm giá'),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Nhập mã giảm giá'),
      'TAKH10020',
    );
    await tester.ensureVisible(find.text('Tìm kiếm'));
    await tester.tap(find.text('Tìm kiếm'));
    await tester.pumpAndSettle();
    expect(find.text('Số lượt còn lại: 7'), findsOneWidget);
    expect(find.text('Tiền giảm: 30.000 đ'), findsOneWidget);
    expect(applies, 0);
    await tester.ensureVisible(find.text('Áp dụng'));
    await tester.tap(find.text('Áp dụng'));
    await tester.pumpAndSettle();
    expect(applies, 1);
    expect(payments, 0);
    expect(find.text('Cần thanh toán: 170.000 đ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
