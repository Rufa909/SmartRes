import 'package:flutter/material.dart';

import 'staff_page.dart';

// Điểm khởi động riêng của app nhân viên trên điện thoại.
void main() => runApp(const StaffApp());

class StaffApp extends StatelessWidget {
  const StaffApp({super.key});
  @override
  Widget build(BuildContext context) => const MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'SmartRes Nhân viên',
    home: StaffPage(),
  );
}
