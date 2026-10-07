import 'package:flutter/material.dart';

import 'kitchen_page.dart';
import 'restaurant_theme.dart';

void main() => runApp(
  MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'SmartRes Bếp',
    theme: restaurantTheme(),
    home: const KitchenPage(),
  ),
);
