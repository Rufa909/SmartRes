import 'dart:convert';

import 'package:http/http.dart' as http;

class MonAn {
  final String id, ten, danhMuc, emoji;
  final int gia;
  final bool conHang;
  const MonAn(
    this.id,
    this.ten,
    this.danhMuc,
    this.emoji,
    this.gia, {
    this.conHang = true,
  });
  factory MonAn.fromJson(Map<String, dynamic> json) => MonAn(
    json['id'] as String,
    json['ten'] as String,
    json['danhMuc'] as String,
    json['emoji'] as String,
    json['gia'] as int,
    conHang: json['conHang'] as bool,
  );
}

class RestaurantApi {
  final http.Client client;
  final String baseUrl;
  RestaurantApi({
    http.Client? client,
    this.baseUrl = const String.fromEnvironment(
      'API_URL',
      defaultValue: 'http://127.0.0.1:4010',
    ),
  }) : client = client ?? http.Client();

  Map<String, dynamic> decode(http.Response response) {
    final body =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(body['message'] ?? 'Yêu cầu thất bại.');
    }
    return body;
  }

  Future<List<MonAn>> fetchMenu() async {
    final response = await client
        .get(Uri.parse('$baseUrl/api/menu'))
        .timeout(const Duration(seconds: 8));
    return (decode(response)['menu'] as List)
        .map((m) => MonAn.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchOrders() async {
    final response = await client
        .get(Uri.parse('$baseUrl/api/orders'))
        .timeout(const Duration(seconds: 8));
    return (decode(response)['orders'] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createOrder(
    Map<MonAn, int> cart,
    String requestId,
  ) async {
    final response = await client
        .post(
          Uri.parse('$baseUrl/api/orders'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'tableId': 'A06',
            'requestId': requestId,
            'items': cart.entries
                .map((e) => {'menuItemId': e.key.id, 'quantity': e.value})
                .toList(),
          }),
        )
        .timeout(const Duration(seconds: 8));
    return decode(response)['order'] as Map<String, dynamic>;
  }
}
