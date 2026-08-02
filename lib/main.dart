// Project Stride — app entry point.
//
// M-2 scope: the shell only. No gameplay, no health integration, no production
// UI. Screens arrive at P-02; the store and engine at F-03.

import 'package:flutter/material.dart';

import 'ui/root_placeholder.dart';

void main() {
  runApp(const StrideApp());
}

class StrideApp extends StatelessWidget {
  const StrideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Project Stride',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3F6B52)),
      ),
      home: const RootPlaceholder(),
    );
  }
}
