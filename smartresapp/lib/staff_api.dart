import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

String newRequestId() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 15) | 64;
  b[8] = (b[8] & 63) | 128;
  final s = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
}

class StaffApi {
  final http.Client client;
  final String baseUrl;
  StaffApi({
    http.Client? client,
    this.baseUrl = const String.fromEnvironment(
      'STAFF_API_URL',
      defaultValue: 'http://127.0.0.1:4000',
    ),
  }) : client = client ?? http.Client();

  Future<Map<String, dynamic>> request(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    try {
      final url = Uri.parse('$baseUrl/api/staff/$path');
      final response =
          await (body == null
                  ? client.get(url)
                  : client.post(
                      url,
                      headers: {'Content-Type': 'application/json'},
                      body: jsonEncode(body),
                    ))
              .timeout(const Duration(seconds: 10));
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StaffApiError(data['message'] as String? ?? 'Yêu cầu thất bại.');
      }
      return data;
    } on StaffApiError {
      rethrow;
    } catch (_) {
      throw StaffApiError(
        'Không kết nối được máy chủ. Kiểm tra backend và kết nối thiết bị.',
      );
    }
  }

  Future<Map<String, dynamic>> snapshot() => request('snapshot');
  Future<void> seat(int tableId, int guests) async {
    await request('tables/$tableId/seat', {'guests': guests});
  }

  Future<void> payment(int tableId) async {
    await request('tables/$tableId/request-payment', {});
  }

  Future<void> serve(int itemId) async {
    await request('items/$itemId/serve', {});
  }

  Future<void> kitchenStatus(int itemId, String status) async {
    await request('items/$itemId/kitchen', {'status': status});
  }

  Future<Map<String, dynamic>> order(
    int tableId,
    Map<int, int> cart,
    String requestId,
  ) => request('orders', {
    'tableId': tableId,
    'requestId': requestId,
    'items': cart.entries
        .map((e) => {'menuItemId': e.key, 'quantity': e.value})
        .toList(),
  });
}

class StaffApiError implements Exception {
  final String message;
  StaffApiError(this.message);
  @override
  String toString() => message;
}
