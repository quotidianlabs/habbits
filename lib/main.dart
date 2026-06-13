import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/habit_list/habit_list_screen.dart';

void main() {
  runApp(const ProviderScope(child: HabbitsApp()));
}

class HabbitsApp extends StatelessWidget {
  const HabbitsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Habbits',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const HabitListScreen(),
    );
  }
}
