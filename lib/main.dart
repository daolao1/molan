import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/db.dart';
import 'ui/assistant_ball.dart';
import 'ui/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // web 上禁用浏览器右键菜单,改用 Flutter 自绘菜单(才能自定义高亮项)
  if (kIsWeb) BrowserContextMenu.disableContextMenu();
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
      locale: const Locale('zh'),
      supportedLocales: const [Locale('zh'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
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

