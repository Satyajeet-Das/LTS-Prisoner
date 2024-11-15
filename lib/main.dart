import 'package:flutter/material.dart';
import 'PrisonerListPage.dart';
import 'Live.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Prisoner Management',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: PrisonerListPage(),
    );
  }
}