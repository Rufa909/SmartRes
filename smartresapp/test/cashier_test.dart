import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartresapp/cashier_page.dart';
import 'package:smartresapp/invoice_document.dart';
import 'package:smartresapp/invoice_dialog.dart';
import 'package:smartresapp/cashier_history_page.dart';
import 'package:smartresapp/staff_api.dart';

Map<String, dynamic> invoice({int pending = 0}) => {
  'invoiceCode': 'HD-12',
  'tableId': 2,
  'tableCode': 'A02',
  'guests': 3,
  'totalAmount': 115000,
  'orderCount': 2,
  'pendingItems': pending,
  'issuedAt': '2026-10-27T12:30:00Z',
  'openedAt': '2026-10-27T11:15:00Z',
  'paymentStatus': 'unpaid',
  'paymentMethod': null,
  'version': List.filled(64, 'a').join(),
  'orderCodes': ['SR-test'],
  'items': [
    {
      'id': 1,
      'name': 'Cơm gà',
      'quantity': 2,
      'unitPrice': 45000,
      'lineTotal': 90000,
    },
    {
      'id': 2,
      'name': 'Trà đào',
      'quantity': 1,
      'unitPrice': 25000,
      'lineTotal': 25000,
    },
  ],
};

http.Response jsonResponse(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  test('Ngày giờ hóa đơn dùng giờ Việt Nam và không có năm', () {
    expect(invoiceDate('2026-12-31T17:05:09Z'), '01/01 00:05:09');
    expect(invoiceDate(null), '—');
  });
  testWidgets('Tăng giảm và xóa trực tiếp trên dòng món, tự lưu tổng tiền', (
    tester,
  ) async {
    var current = invoice();
    var saves = 0;
    var failNext = false;
    final client = MockClient((req) async {
      if (req.method != 'POST') return jsonResponse({'invoice': current});
      if (failNext) {
        return jsonResponse({'message': 'Hóa đơn đã thay đổi'}, 409);
      }
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      expect(body['version'], current['version']);
      final updated = (body['items'] as List).map((line) {
        final original = (current['items'] as List).firstWhere(
          (item) => item['id'] == line['itemId'],
        ) as Map<String, dynamic>;
        return {
          ...original,
          'quantity': line['quantity'],
          'lineTotal':
              (line['quantity'] as num) * (original['unitPrice'] as num),
        };
      }).toList();
      saves++;
      current = {
        ...current,
        'items': updated,
        'version': List.filled(64, '$saves').join(),
        'totalAmount': updated.fold<num>(
          0,
          (sum, item) => sum + (item['lineTotal'] as num),
        ),
      };
      return jsonResponse({'invoice': current});
    });
    addTearDown(client.close);
    await tester.pumpWidget(
      MaterialApp(
        home: InvoiceDialog(
          api: StaffApi(client: client),
          tableId: 2,
          onPaid: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tăng Cơm gà'));
    await tester.pumpAndSettle();
    expect(find.text('Tổng tiền: 160.000 đ'), findsOneWidget);
    await tester.tap(find.byTooltip('Giảm Cơm gà'));
    await tester.pumpAndSettle();
    expect(find.text('Tổng tiền: 115.000 đ'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Xóa Trà đào'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Xóa Trà đào'));
    await tester.pumpAndSettle();
    expect(find.text('Trà đào'), findsNothing);
    expect(find.text('Tổng tiền: 90.000 đ'), findsOneWidget);
    expect(saves, 3);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.delete_outline),
          )
          .onPressed,
      isNull,
    );
    failNext = true;
    await tester.ensureVisible(find.byTooltip('Tăng Cơm gà'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tăng Cơm gà'));
    await tester.pumpAndSettle();
    expect(find.text('Tổng tiền: 90.000 đ'), findsOneWidget);
    expect(find.text('Hóa đơn đã thay đổi'), findsOneWidget);
  });
  testWidgets('Thêm món chỉ gửi món mới và ghi chú, giữ nguyên các món cũ', (
    tester,
  ) async {
    var saves = 0;
    final changed = {
      ...invoice(),
      'totalAmount': 125000,
      'pendingItems': 1,
      'items': [
        ...(invoice()['items'] as List),
        {
          'id': 3,
          'name': 'Nước suối',
          'quantity': 1,
          'unitPrice': 10000,
          'lineTotal': 10000,
          'note': 'Không đá',
        },
      ],
    };
    final client = MockClient((req) async {
      if (req.url.path.endsWith('/menu')) {
        return jsonResponse({
          'items': [
            {'id': 3, 'name': 'Nước suối', 'price': 10000},
          ],
        });
      }
      if (req.method == 'POST') {
        saves++;
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body['items'], [
          {'itemId': 1, 'quantity': 2},
          {'itemId': 2, 'quantity': 1},
          {'menuItemId': 3, 'quantity': 1, 'note': 'Không đá'},
        ]);
        return jsonResponse({'invoice': changed});
      }
      return jsonResponse({'invoice': invoice()});
    });
    addTearDown(client.close);
    await tester.pumpWidget(
      MaterialApp(
        home: InvoiceDialog(
          api: StaffApi(client: client),
          tableId: 2,
          onPaid: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chỉnh sửa món / số lượng'), findsNothing);
    // Quantity controls share the same row as the dish name.
    expect(
      (tester.getCenter(find.text('Cơm gà')).dy -
              tester.getCenter(find.byTooltip('Tăng Cơm gà')).dy)
          .abs(),
      lessThan(1),
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Thêm món'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chọn món'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nước suối'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'Không đá');
    await tester.tap(find.text('Thêm vào hóa đơn'));
    await tester.pumpAndSettle();
    expect(saves, 1);
    expect(find.text('Tổng tiền: 125.000 đ'), findsOneWidget);
    expect(find.text('Ghi chú: Không đá'), findsOneWidget);
  });

  testWidgets(
    'Giảm giá dưới phương thức thanh toán: nhập %, voucher và bỏ giảm',
    (tester) async {
      var current = {
        ...invoice(),
        'subtotalAmount': 115000,
        'discountAmount': 0,
        'discountPercentage': 0,
        'discountMode': 'none',
      };
      var requests = 0;
      final client = MockClient((req) async {
        if (req.method != 'POST') {
          return jsonResponse({'invoice': current});
        }
        requests++;
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(req.url.path, '/api/staff/tables/2/discount');
        expect(body['version'], current['version']);
        if (body['code'] == 'SAI') {
          return jsonResponse({'message': 'Voucher không hợp lệ'}, 409);
        }
        final percent = body['mode'] == 'manual'
            ? body['percentage'] as num
            : body['mode'] == 'voucher'
            ? 20
            : 0;
        current = {
          ...current,
          'version': List.filled(64, '$requests').join(),
          'discountPercentage': percent,
          'discountMode': body['mode'],
          'voucherCode': body['mode'] == 'voucher' ? body['code'] : null,
          'discountAmount': 115000 * percent / 100,
          'totalAmount': 115000 * (100 - percent) / 100,
        };
        return jsonResponse({'invoice': current});
      });
      addTearDown(client.close);
      await tester.pumpWidget(
        MaterialApp(
          home: InvoiceDialog(
            api: StaffApi(client: client),
            tableId: 2,
            onPaid: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('manual-discount')), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('toggle-discount')));
      await tester.tap(find.byKey(const Key('toggle-discount')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('manual-discount')));
      await tester.enterText(find.byKey(const Key('manual-discount')), '101');
      await tester.ensureVisible(find.text('Áp dụng'));
      await tester.tap(find.text('Áp dụng'));
      await tester.pumpAndSettle();
      expect(requests, 0);
      await tester.enterText(find.byKey(const Key('manual-discount')), '10');
      await tester.tap(find.text('Áp dụng'));
      await tester.pumpAndSettle();
      expect(find.text('Cần thanh toán: 103.500 đ'), findsOneWidget);
      await tester.ensureVisible(find.text('Mã voucher'));
      await tester.tap(find.text('Mã voucher'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('voucher-code')), 'SAI');
      await tester.ensureVisible(find.text('Áp dụng'));
      await tester.tap(find.text('Áp dụng'));
      await tester.pumpAndSettle();
      expect(find.text('Voucher không hợp lệ'), findsOneWidget);
      expect(find.text('Cần thanh toán: 103.500 đ'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('voucher-code')), 'TEST20');
      await tester.tap(find.text('Áp dụng'));
      await tester.pumpAndSettle();
      expect(find.text('Cần thanh toán: 92.000 đ'), findsOneWidget);
      await tester.ensureVisible(find.text('Bỏ giảm giá'));
      await tester.tap(find.text('Bỏ giảm giá'));
      await tester.pumpAndSettle();
      expect(find.text('Cần thanh toán: 115.000 đ'), findsOneWidget);
    },
  );
  testWidgets('Lịch sử tải từ máy chủ và hóa đơn cũ chỉ xem, in lại', (
    tester,
  ) async {
    final paid = {
      ...invoice(),
      'paymentStatus': 'paid',
      'paymentMethod': 'cash',
      'cashierName': 'Thu ngân test',
    };
    var loads = 0;
    final client = MockClient((req) async {
      if (req.url.path.endsWith('/history/5')) {
        return jsonResponse({'invoice': paid});
      }
      loads++;
      return jsonResponse({
        'invoices': [
          {
            'historyId': 5,
            'invoiceCode': 'HD-12',
            'tableCode': 'A02',
            'totalAmount': 115000,
            'paidAt': '2026-10-27T12:30:00Z',
            'paymentMethod': 'cash',
          },
        ],
        'total': 1,
      });
    });
    addTearDown(client.close);
    await tester.pumpWidget(
      MaterialApp(
        home: CashierHistoryPage(api: StaffApi(client: client)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('HD-12 • Bàn A02'), findsOneWidget);
    await tester.tap(find.text('HD-12 • Bàn A02'));
    await tester.pumpAndSettle();
    expect(find.text('In hóa đơn'), findsOneWidget);
    expect(find.text('Chỉnh sửa món / số lượng'), findsNothing);
    expect(find.byTooltip('Tăng Cơm gà'), findsNothing);
    expect(find.text('Thu ngân: Thu ngân test'), findsOneWidget);
    await tester.tap(find.text('Đóng'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(
        home: CashierHistoryPage(api: StaffApi(client: client)),
      ),
    );
    await tester.pumpAndSettle();
    expect(loads, 2);
    expect(find.text('HD-12 • Bàn A02'), findsOneWidget);
  });
  testWidgets('Android nhận đúng khổ bill 80 mm thay cho giấy mặc định', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const channel = MethodChannel('smartres/receipt_printing');
    MethodCall? request;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      request = call;
      return null;
    });
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
    });
    try {
      await printInvoice(invoice());
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
    expect(request!.method, 'printReceipt');
    final args = request!.arguments as Map;
    expect(args['width'] as double, closeTo(80 * 72 / 25.4, 0.01));
    expect((args['height'] as double).isFinite, isTrue);
    final bytes = args['bytes'] as Uint8List;
    final media = RegExp(r'/MediaBox\s*\[\s*0\s+0\s+([\d.]+)\s+([\d.]+)\s*\]')
        .firstMatch(latin1.decode(bytes))!;
    expect(args['width'], closeTo(double.parse(media[1]!), 0.01));
    expect(args['height'], closeTo(double.parse(media[2]!), 0.01));
  });
  testWidgets('Xem chi tiết, chọn chuyển khoản, thanh toán rồi mở lại để in', (
    tester,
  ) async {
    var paid = false;
    final client = MockClient((req) async {
      if (req.method == 'POST') {
        expect(req.url.path, '/api/staff/tables/2/pay');
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body['paymentMethod'], 'bank_transfer');
        expect(body['orderCodes'], ['SR-test']);
        paid = true;
        return jsonResponse({
          'invoice': {
            ...invoice(),
            'paymentStatus': 'paid',
            'paymentMethod': 'bank_transfer',
            'paidAt': '2026-10-27T12:31:00Z',
          },
        });
      }
      if (req.url.path.endsWith('/invoice')) {
        return jsonResponse({'invoice': invoice()});
      }
      return jsonResponse({
        'tables': paid ? [] : [invoice()],
      });
    });
    addTearDown(client.close);
    await tester.pumpWidget(
      MaterialApp(
        home: CashierPage(api: StaffApi(client: client), autoRefresh: false),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xem chi tiết hóa đơn'));
    await tester.pumpAndSettle();
    expect(paid, isFalse);
    expect(find.text('Cơm gà'), findsOneWidget);
    expect(find.text('Trà đào'), findsOneWidget);
    expect(find.textContaining('27/10 19:30:00'), findsOneWidget);
    expect(find.textContaining('Nhận bàn: 27/10 18:15:00'), findsOneWidget);
    expect(find.text('Tổng tiền: 115.000 đ'), findsOneWidget);
    expect(find.text('In hóa đơn'), findsNothing);
    await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chuyển khoản').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận thanh toán'));
    await tester.pumpAndSettle();
    expect(paid, isTrue);
    expect(find.text('Phương thức thanh toán: Chuyển khoản'), findsOneWidget);
    expect(find.text('In hóa đơn'), findsOneWidget);
    await tester.tap(find.text('Đóng'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('HD-12 • Bàn A02'));
    await tester.pumpAndSettle();
    expect(find.text('In hóa đơn'), findsOneWidget);
    expect(find.text('Cơm gà'), findsOneWidget);
  });

  testWidgets(
    'Còn món chưa phục vụ: hủy không thu tiền, xác nhận thì thanh toán',
    (tester) async {
      var payments = 0;
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/pay')) {
          payments++;
          expect(jsonDecode(req.body)['confirmUnserved'], isTrue);
          return jsonResponse({
            'invoice': {
              ...invoice(pending: 2),
              'paymentStatus': 'paid',
              'paymentMethod': 'cash',
            },
          });
        }
        return jsonResponse(
          req.url.path.endsWith('/invoice')
              ? {'invoice': invoice(pending: 2)}
              : {
                  'tables': [invoice(pending: 2)],
                },
        );
      });
      addTearDown(client.close);
      await tester.pumpWidget(
        MaterialApp(
          home: CashierPage(api: StaffApi(client: client), autoRefresh: false),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Thanh toán'),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.text('Xem chi tiết hóa đơn'));
      await tester.pumpAndSettle();
      expect(find.text('Cơm gà'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Xác nhận thanh toán'),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(
        find.widgetWithText(FilledButton, 'Xác nhận thanh toán'),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Đơn hàng còn 2 món chưa phục vụ. Bạn có chắc chắn muốn thanh toán ngay không?',
        ),
        findsOneWidget,
      );
      expect(payments, 0);
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(payments, 0);
      await tester.tap(
        find.widgetWithText(FilledButton, 'Xác nhận thanh toán'),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Xác nhận thanh toán').last,
      );
      await tester.pumpAndSettle();
      expect(payments, 1);
      expect(find.text('Đã thanh toán'), findsOneWidget);
    },
  );

  testWidgets('Lỗi tải chi tiết có thể thử lại', (tester) async {
    var fail = true;
    final client = MockClient((req) async {
      if (!req.url.path.endsWith('/invoice')) {
        return jsonResponse({
          'tables': [invoice()],
        });
      }
      return fail
          ? jsonResponse({'message': 'Mất kết nối'}, 503)
          : jsonResponse({'invoice': invoice()});
    });
    addTearDown(client.close);
    await tester.pumpWidget(
      MaterialApp(
        home: CashierPage(api: StaffApi(client: client), autoRefresh: false),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xem chi tiết hóa đơn'));
    await tester.pumpAndSettle();
    expect(find.text('Mất kết nối'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Cơm gà'), findsOneWidget);
  });

  testWidgets('Bill nhiệt 80 mm tự co chiều dài theo số món', (tester) async {
    final bill = invoice();
    bill['paymentStatus'] = 'paid';
    bill['paymentMethod'] = 'cash';
    final shortBytes = await buildInvoicePdf(bill);
    List<double> pageSize(List<int> bytes) {
      final match = RegExp(r'/MediaBox\s*\[\s*0\s+0\s+([\d.]+)\s+([\d.]+)\s*\]')
          .firstMatch(latin1.decode(bytes))!;
      return [double.parse(match[1]!), double.parse(match[2]!)];
    }

    final shortSize = pageSize(shortBytes);
    expect(shortSize[0], closeTo(80 * 72 / 25.4, 0.01));
    expect(shortSize[1], lessThan(500));
    bill['items'] = List.generate(
      100,
      (_) => {
        ...(invoice()['items'] as List).first as Map<String, dynamic>,
        'name': 'Cơm gà nướng muối ớt kèm rau củ theo mùa và nước sốt đặc biệt của nhà hàng',
      },
    );
    final bytes = await buildInvoicePdf(bill);
    expect(ascii.decode(bytes.take(4).toList()), '%PDF');
    final longSize = pageSize(bytes);
    expect(longSize[0], closeTo(shortSize[0], 0.01));
    expect(longSize[1], greaterThan(shortSize[1]));
    if (const bool.fromEnvironment('WRITE_DISCOUNT_SAMPLE')) {
      final sample = {
        ...invoice(),
        'paymentStatus': 'paid',
        'paymentMethod': 'cash',
        'subtotalAmount': 115000,
        'discountAmount': 11500,
        'discountPercentage': 10,
        'discountMode': 'manual',
        'totalAmount': 103500,
        'items': [
          (invoice()['items'] as List).first,
          {
            ...(invoice()['items'] as List).last as Map<String, dynamic>,
            'note': 'Không đá, ít đường',
          },
        ],
      };
      final sampleBytes = await buildInvoicePdf(sample);
      await tester.runAsync(() async {
        await Directory('../tmp/pdfs').create(recursive: true);
        await File('../tmp/pdfs/thermal-discount-sample.pdf')
            .writeAsBytes(sampleBytes);
      });
    }
    if (const bool.fromEnvironment('WRITE_RECEIPT_SAMPLE')) {
      await tester.runAsync(() async {
        await Directory('../output/pdf').create(recursive: true);
        await File('../output/pdf/thermal-receipt.pdf')
            .writeAsBytes(shortBytes);
        await Directory('../tmp/pdfs').create(recursive: true);
        await File('../tmp/pdfs/thermal-receipt-long.pdf').writeAsBytes(bytes);
      });
    }
  });
}
