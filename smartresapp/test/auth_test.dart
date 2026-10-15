import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartresapp/staff_api.dart';

void main() {
  test('Đăng nhập lưu token và gắn token vào API bảo vệ', () async {
    String? authorization;
    final client = MockClient((request) async {
      if (request.url.path == '/api/auth/login') {
        return http.Response(jsonEncode({
          'token': 'demo-token',
          'user': {'id': 1, 'username': 'nhanvien', 'displayName': 'Nhân viên', 'role': 'staff'},
        }), 200, headers: {'content-type': 'application/json'});
      }
      authorization = request.headers['authorization'];
      return http.Response('{"tables":[],"menu":[],"items":[]}', 200);
    });
    addTearDown(client.close);
    final api = StaffApi(client: client, baseUrl: 'https://example.com');
    final user = await api.login('nhanvien', 'Staff@123');
    expect(user['user']['role'], 'staff');
    await api.snapshot();
    expect(authorization, 'Bearer demo-token');
  });
}
