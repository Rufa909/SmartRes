import 'package:flutter/material.dart';

import 'restaurant_theme.dart';
import 'staff_api.dart';

class LoginPage extends StatefulWidget {
  final StaffApi api;
  final Future<void> Function(Map<String, dynamic> user) onLoggedIn;
  const LoginPage({super.key, required this.api, required this.onLoggedIn});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final username = TextEditingController();
  final password = TextEditingController();
  bool loading = false, obscure = true;
  String? error;

  @override
  void dispose() { username.dispose(); password.dispose(); super.dispose(); }

  Future<void> submit() async {
    if (username.text.trim().isEmpty || password.text.isEmpty) {
      setState(() => error = 'Nhập tên đăng nhập và mật khẩu.');
      return;
    }
    setState(() { loading = true; error = null; });
    try {
      final data = await widget.api.login(username.text.trim(), password.text);
      if (mounted) await widget.onLoggedIn(data['user'] as Map<String, dynamic>);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally { if (mounted) setState(() => loading = false); }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: restaurantTheme(),
    child: Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.restaurant, size: 52, color: brandOrange),
                    const SizedBox(height: 12),
                    const Text('SmartRes', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    const Text('Đăng nhập hệ thống vận hành', textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    TextField(controller: username, enabled: !loading, decoration: const InputDecoration(labelText: 'Tên đăng nhập', prefixIcon: Icon(Icons.person_outline))),
                    const SizedBox(height: 12),
                    TextField(controller: password, enabled: !loading, obscureText: obscure, onSubmitted: (_) => submit(), decoration: InputDecoration(labelText: 'Mật khẩu', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => obscure = !obscure), icon: Icon(obscure ? Icons.visibility : Icons.visibility_off)))),
                    if (error != null) ...[const SizedBox(height: 12), Text(error!, style: const TextStyle(color: Colors.red))],
                    const SizedBox(height: 20),
                    FilledButton.icon(onPressed: loading ? null : submit, icon: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.login), label: const Text('Đăng nhập')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
