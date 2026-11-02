import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartresapp/personnel_management_page.dart';
import 'package:smartresapp/staff_api.dart';

http.Response response(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  testWidgets(
    'Quản lý thêm, sửa vai trò, cấp lại mật khẩu và xóa tài khoản trên màn hình nhỏ',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final users = <Map<String, dynamic>>[
        {
          'id': 1,
          'username': 'nv01',
          'displayName': 'Nguyễn An',
          'role': 'staff',
          'version': 0,
        },
      ];
      var resets = 0, deletes = 0;
      final client = MockClient((req) async {
        expect(req.headers['authorization'], 'Bearer manager-test');
        if (req.method == 'GET') return response({'users': users});
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        if (req.url.path.endsWith('/password')) {
          resets++;
          expect(body, {'version': 1, 'password': 'Reset@123'});
          users.last['version'] = 2;
          return response({'ok': true});
        }
        if (req.url.path.endsWith('/delete')) {
          deletes++;
          expect(body['version'], 2);
          users.removeLast();
          return response({'ok': true});
        }
        if (req.url.path.endsWith('/users')) {
          expect(body['role'], 'kitchen');
          expect(body['password'], 'Start@123');
          users.add({
            'id': 2,
            'username': body['username'],
            'displayName': body['displayName'],
            'role': body['role'],
            'version': 0,
          });
        } else {
          expect(req.url.path, '/api/staff/management/users/2');
          expect(body['version'], 0);
          expect(body.containsKey('password'), isFalse);
          users.last.addAll({...body, 'version': 1});
        }
        return response({'user': users.last});
      });
      addTearDown(client.close);
      await tester.pumpWidget(
        MaterialApp(
          home: PersonnelManagementPage(
            api: StaffApi(client: client)..token = 'manager-test',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nguyễn An'), findsOneWidget);
      await tester.tap(find.text('Thêm tài khoản'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('employee-name')), 'Trần Hà');
      await tester.enterText(
        find.byKey(const Key('employee-username')),
        'bep02',
      );
      await tester.ensureVisible(find.byKey(const Key('employee-role')));
      await tester.tap(find.byKey(const Key('employee-role')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bếp').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('employee-password')));
      await tester.enterText(
        find.byKey(const Key('employee-password')),
        'Start@123',
      );
      await tester.ensureVisible(
        find.byKey(const Key('employee-password-repeat')),
      );
      await tester.enterText(
        find.byKey(const Key('employee-password-repeat')),
        'Start@123',
      );
      await tester.tap(find.text('Lưu tài khoản'));
      await tester.pumpAndSettle();
      expect(find.text('Đã tạo tài khoản'), findsOneWidget);
      expect(find.text('Mật khẩu: Start@123'), findsOneWidget);
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
      expect(find.text('Trần Hà'), findsOneWidget);
      await tester.tap(find.byTooltip('Thao tác bep02'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sửa tài khoản'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('employee-name')),
        'Trần Hà mới',
      );
      await tester.tap(find.byKey(const Key('employee-role')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thu ngân').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu tài khoản'));
      await tester.pumpAndSettle();
      expect(find.text('bep02 · Thu ngân'), findsOneWidget);
      await tester.tap(find.byTooltip('Thao tác bep02'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cấp lại mật khẩu'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('employee-password')),
        'Reset@123',
      );
      await tester.enterText(
        find.byKey(const Key('employee-password-repeat')),
        'Wrong@123',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Cấp lại mật khẩu'));
      await tester.pumpAndSettle();
      expect(find.text('Mật khẩu nhập lại chưa khớp.'), findsOneWidget);
      expect(resets, 0);
      await tester.enterText(
        find.byKey(const Key('employee-password-repeat')),
        'Reset@123',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Cấp lại mật khẩu'));
      await tester.pumpAndSettle();
      expect(find.text('Đã cấp lại mật khẩu'), findsOneWidget);
      expect(find.text('Mật khẩu: Reset@123'), findsOneWidget);
      expect(resets, 1);
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Thao tác bep02'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xóa tài khoản'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(deletes, 0);
      await tester.tap(find.byTooltip('Thao tác bep02'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xóa tài khoản'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Xóa tài khoản'));
      await tester.pumpAndSettle();
      expect(deletes, 1);
      expect(find.text('Trần Hà mới'), findsNothing);
      expect(find.text('Nguyễn An'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Lỗi lưu giữ nguyên biểu mẫu, tìm và lọc nhân sự đúng vai trò', (
    tester,
  ) async {
    final client = MockClient(
      (req) async => req.method == 'POST'
          ? response({'message': 'Tên đăng nhập đã được sử dụng.'}, 409)
          : response({
              'users': [
                {
                  'id': 1,
                  'username': 'nv01',
                  'displayName': 'Nguyễn An',
                  'role': 'staff',
                  'version': 0,
                },
                {
                  'id': 2,
                  'username': 'bep01',
                  'displayName': 'Trần Bình',
                  'role': 'kitchen',
                  'version': 0,
                },
              ],
            }),
    );
    addTearDown(client.close);
    await tester.pumpWidget(
      MaterialApp(
        home: PersonnelManagementPage(api: StaffApi(client: client)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Bếp'));
    await tester.pumpAndSettle();
    expect(find.text('Nguyễn An'), findsNothing);
    expect(find.text('Trần Bình'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'binh');
    await tester.pumpAndSettle();
    expect(find.text('Trần Bình'), findsOneWidget);
    await tester.tap(find.text('Thêm tài khoản'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('employee-name')),
      'Tài khoản mới',
    );
    await tester.enterText(find.byKey(const Key('employee-username')), 'bep01');
    await tester.ensureVisible(find.byKey(const Key('employee-password')));
    await tester.enterText(
      find.byKey(const Key('employee-password')),
      'Start@123',
    );
    await tester.ensureVisible(
      find.byKey(const Key('employee-password-repeat')),
    );
    await tester.enterText(
      find.byKey(const Key('employee-password-repeat')),
      'Start@123',
    );
    await tester.tap(find.text('Lưu tài khoản'));
    await tester.pumpAndSettle();
    expect(find.text('Tên đăng nhập đã được sử dụng.'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('employee-username')))
          .controller!
          .text,
      'bep01',
    );
    expect(find.text('Đã tạo tài khoản'), findsNothing);
  });
}
