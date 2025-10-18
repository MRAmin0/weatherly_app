import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'weather_screen.dart';
import 'weather_store.dart';
import 'config_reader.dart';

void main() async {
  // اطمینان از مقداردهی اولیه فلاتر قبل از فراخوانی متدهای async
  WidgetsFlutterBinding.ensureInitialized();
  
  // بارگذاری کلیدهای API
  await ConfigReader.initialize(); 

  runApp(
    ChangeNotifierProvider(
      create: (context) => WeatherStore(), // تزریق Store به درخت ویجت‌ها
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _changeTheme(ThemeMode themeMode) {
    setState(() {
      _themeMode = themeMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weatherly',
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF0F4F8),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF121212),
        inputDecorationTheme: const InputDecorationTheme(
          hintStyle: TextStyle(color: Colors.grey),
          labelStyle: TextStyle(color: Colors.white70),
        ),
      ),
      themeMode: _themeMode,
      home: WeatherScreen(
        currentThemeMode: _themeMode,
        onThemeChanged: _changeTheme,
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}