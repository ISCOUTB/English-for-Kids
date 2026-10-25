import 'package:flutter/material.dart';

const List<Color> kCardColors = [
  Color(0xFFFFE0B2),
  Color(0xFFC8E6C9),
  Color(0xFFBBDEFB),
  Color(0xFFF8BBD0),
  Color(0xFFD1C4E9),
  Color(0xFFFFF59D),
  Color(0xFFB2EBF2),
  Color(0xFFFFCCBC),
];

Color cardColor(int index) => kCardColors[index % kCardColors.length];
