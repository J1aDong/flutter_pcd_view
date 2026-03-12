import 'package:flutter/material.dart';
import 'package:flutter_pcd_view/pcd_view.dart';

import 'screens/tab_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PcdParser.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PCD Viewer Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const TabScreen(),
    );
  }
}
