import 'package:flutter/material.dart';
import 'PrisonerListPage.dart';
import 'Live.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
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