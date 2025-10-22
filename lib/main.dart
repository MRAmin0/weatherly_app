import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'weather_screen.dart';
import 'weather_store.dart';
import 'config_reader.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ConfigReader.initialize();

  final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

  runApp(
    ChangeNotifierProvider(
      create: (_) => WeatherStore(),
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeNotifier,
        builder: (context, themeMode, _) {
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
            themeMode: themeMode,
            home: WeatherScreen(
              currentThemeMode: themeMode,
              onThemeChanged: (newMode) => themeNotifier.value = newMode,
            ),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    ),
  );
}
