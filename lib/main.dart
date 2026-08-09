import 'package:flutter/material.dart';

import 'data/db.dart';
import 'ui/assistant_ball.dart';
import 'ui/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MolanApp(db: AppDatabase()));
}

class MolanApp extends StatelessWidget {
  MolanApp({super.key, required this.db});

  final AppDatabase db;
  final _navKey = GlobalKey<NavigatorState>();
  final _smKey = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '墨澜',
      navigatorKey: _navKey,
      scaffoldMessengerKey: _smKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.indigo, brightness: Brightness.dark),
      ),
      home: HomePage(db: db),
      builder: (context, child) => Stack(
        children: [
          ?child,
          AssistantBall(db: db, navKey: _navKey, smKey: _smKey),
        ],
      ),
    );
  }
}

