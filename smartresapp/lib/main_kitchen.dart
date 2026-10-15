import 'package:flutter/material.dart';

import 'kitchen_page.dart';
import 'restaurant_theme.dart';
import 'login_page.dart';
import 'staff_api.dart';

void main() => runApp(
  MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'SmartRes Bếp',
    theme: restaurantTheme(),
    home: const KitchenAuthGate(),
  ),
);

class KitchenAuthGate extends StatefulWidget {
  const KitchenAuthGate({super.key});
  @override State<KitchenAuthGate> createState() => _KitchenAuthGateState();
}
class _KitchenAuthGateState extends State<KitchenAuthGate> {
  final api = StaffApi();
  bool loggedIn = false;
  @override
  void dispose() { api.client.close(); super.dispose(); }
  @override
  Widget build(BuildContext context) => loggedIn
      ? KitchenPage(api: api)
      : LoginPage(api: api, onLoggedIn: (user) async {
          if (user['role'] != 'kitchen' && user['role'] != 'manager') {
            throw StaffApiError('Tài khoản này không thuộc nhóm bếp.');
          }
          setState(() => loggedIn = true);
        });
}
