import 'package:flutter/material.dart';

import 'staff_page.dart';
import 'kitchen_page.dart';
import 'login_page.dart';
import 'staff_api.dart';
import 'restaurant_theme.dart';

// Điểm khởi động riêng của app nhân viên trên điện thoại.
void main() => runApp(const StaffApp());

class StaffApp extends StatelessWidget {
  const StaffApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'SmartRes Nhân viên',
    theme: restaurantTheme(),
    home: const StaffAuthGate(),
  );
}

class StaffAuthGate extends StatefulWidget {
  const StaffAuthGate({super.key});
  @override State<StaffAuthGate> createState() => _StaffAuthGateState();
}

class _StaffAuthGateState extends State<StaffAuthGate> {
  final api = StaffApi();
  Map<String, dynamic>? user;
  @override
  void dispose() { api.client.close(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    if (user == null) return LoginPage(api: api, onLoggedIn: (value) async => setState(() => user = value));
    return user!['role'] == 'kitchen' ? KitchenPage(api: api) : StaffPage(api: api);
  }
}
