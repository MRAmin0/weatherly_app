import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'screens/weather_screen.dart';
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
            title: 'هواشناسی',
            debugShowCheckedModeBanner: false,
            themeMode: themeMode,

            // 💡 پشتیبانی کامل از فارسی و راست‌به‌چپ
            locale: const Locale('fa', 'IR'),
            supportedLocales: const [
              Locale('fa', 'IR'),
              Locale('en', 'US'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],

            // 🌗 تم روشن و تاریک
            theme: ThemeData(
              useMaterial3: true,
              fontFamily: 'Vazir',
              brightness: Brightness.light,
              primarySwatch: Colors.blue,
              scaffoldBackgroundColor: const Color(0xFFF0F4F8),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              fontFamily: 'Vazir',
              brightness: Brightness.dark,
              primarySwatch: Colors.blue,
              scaffoldBackgroundColor: const Color(0xFF121212),
              inputDecorationTheme: const InputDecorationTheme(
                hintStyle: TextStyle(color: Colors.grey),
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),

            // 🔄 اطمینان از راست‌به‌چپ بودن کل اپ
            builder: (context, child) {
              return Directionality(
                textDirection: TextDirection.rtl,
                child: child!,
              );
            },

            // 🏙️ صفحه اصلی
            home: WeatherScreen(
              currentThemeMode: themeMode,
              onThemeChanged: (newMode) => themeNotifier.value = newMode,
            ),
          );
        },
      ),
    ),
  );
}
