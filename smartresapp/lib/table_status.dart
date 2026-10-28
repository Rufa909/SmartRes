import 'package:flutter/material.dart';

import 'restaurant_theme.dart';

String tableStatus(String status) => switch (status) {
  'available' => 'Trống',
  'dining' => 'Đang phục vụ',
  'waiting_payment' => 'Chờ thanh toán',
  _ => 'Tạm khóa',
};

Color tableStatusColor(String status) => switch (status) {
  'available' => brandOrange,
  'waiting_payment' => const Color(0xFFB06B16),
  _ => const Color(0xFF3665AC),
};
