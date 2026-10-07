import 'package:flutter/material.dart';

const brandOrange = Color(0xFFFF5A3C);
const ink = Color(0xFF20252B);
const canvas = Color(0xFFF6F7F9);
ThemeData restaurantTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: brandOrange,
    primary: brandOrange,
  ),
  scaffoldBackgroundColor: canvas,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
  ),
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: Colors.white,
    indicatorColor: Color(0xFFFFEEE9),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
    ),
  ),
  chipTheme: ChipThemeData(
    selectedColor: brandOrange.withValues(alpha: .15),
    backgroundColor: Colors.white,
    side: const BorderSide(color: Color(0xFFE5E7EB)),
    shape: const StadiumBorder(),
  ),
);

String searchText(String value) {
  var text = value.toLowerCase().trim();
  const groups = [
    'àáạảãâầấậẩẫăằắặẳẵ',
    'èéẹẻẽêềếệểễ',
    'ìíịỉĩ',
    'òóọỏõôồốộổỗơờớợởỡ',
    'ùúụủũưừứựửữ',
    'ỳýỵỷỹ',
    'đ',
  ];
  const letters = ['a', 'e', 'i', 'o', 'u', 'y', 'd'];
  for (var i = 0; i < groups.length; i++) {
    for (final char in groups[i].split('')) {
      text = text.replaceAll(char, letters[i]);
    }
  }
  return text
      .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
      .replaceAll(RegExp(r'\s+'), ' ');
}

bool matchesSearch(String value, String query) =>
    searchText(query)
        .split(' ')
        .every((word) => searchText(value).contains(word));
