import 'package:flutter/material.dart';
import 'package:outsourcing/entry_screen.dart';
import 'dashboard_screen.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: false,
      ),
      debugShowCheckedModeBanner: false,
      home: EntryScreen(),
    );
  }
}


