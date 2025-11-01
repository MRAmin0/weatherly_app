import 'dart:math';
import 'package:flutter/material.dart';
import '../weather_store.dart';



class WeatherBackground extends StatelessWidget {
  final WeatherType weatherType;
  final bool isDarkMode;
  const WeatherBackground({
    super.key,
    required this.weatherType,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    switch (weatherType) {
      case WeatherType.clear:
      case WeatherType.unknown:
        return SunnyBackground(isDarkMode: isDarkMode);
      case WeatherType.clouds:
        return CloudyBackground(isDarkMode: isDarkMode);
      case WeatherType.rain:
      case WeatherType.drizzle:
      case WeatherType.thunderstorm:
        return Stack(
          children: [
            CloudyBackground(isDarkMode: isDarkMode),
            const SimpleRainBackground(),
          ],
        );
      case WeatherType.snow:
        return Stack(
          children: [
            CloudyBackground(isDarkMode: isDarkMode),
            const SimpleSnowBackground(),
          ],
        );
    }
  }
}

class SunnyBackground extends StatelessWidget {
  final bool isDarkMode;
  const SunnyBackground({super.key, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDarkMode
              ? [const Color(0xFF233053), const Color(0xFF000000)]
              : [const Color(0xFF4A90E2), const Color(0xFF81C7F5)],
        ),
      ),
    );
  }
}

class CloudyBackground extends StatelessWidget {
  final bool isDarkMode;
  const CloudyBackground({super.key, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDarkMode
              ? [const Color(0xFF3C4E68), const Color(0xFF202A38)]
              : [const Color(0xFF7D97B3), const Color(0xFFB3C6D9)],
        ),
      ),
    );
  }
}

class SimpleRainBackground extends StatefulWidget {
  const SimpleRainBackground({super.key});
  @override
  State<SimpleRainBackground> createState() => _SimpleRainBackgroundState();
}

class _SimpleRainBackgroundState extends State<SimpleRainBackground> {
  final Random _rand = Random();
  List<double> _positions = [];

  @override
  void initState() {
    super.initState();
    _positions = List.generate(10, (_) => -_rand.nextDouble() * 200);
    _animate();
  }

  void _animate() async {
    while (mounted) {
      await Future.delayed(const Duration(milliseconds: 50));
      setState(() {
        for (int i = 0; i < _positions.length; i++) {
          _positions[i] += 15;
          if (_positions[i] > MediaQuery.of(context).size.height) {
            _positions[i] = -_rand.nextDouble() * 200;
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Stack(
      children: List.generate(_positions.length, (i) {
        final left = _rand.nextDouble() * width;
        return Positioned(
          top: _positions[i],
          left: left,
          child: Icon(Icons.water_drop, color: Colors.blue.shade200, size: 18),
        );
      }),
    );
  }
}

class SimpleSnowBackground extends StatefulWidget {
  const SimpleSnowBackground({super.key});
  @override
  State<SimpleSnowBackground> createState() => _SimpleSnowBackgroundState();
}

class _SimpleSnowBackgroundState extends State<SimpleSnowBackground> {
  final Random _rand = Random();
  List<double> _positions = [];

  @override
  void initState() {
    super.initState();
    _positions = List.generate(10, (_) => -_rand.nextDouble() * 200);
    _animate();
  }

  void _animate() async {
    while (mounted) {
      await Future.delayed(const Duration(milliseconds: 100));
      setState(() {
        for (int i = 0; i < _positions.length; i++) {
          _positions[i] += 5;
          if (_positions[i] > MediaQuery.of(context).size.height) {
            _positions[i] = -_rand.nextDouble() * 200;
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Stack(
      children: List.generate(_positions.length, (i) {
        final left = _rand.nextDouble() * width;
        return Positioned(
          top: _positions[i],
          left: left,
          child: const Icon(Icons.ac_unit, color: Colors.white70, size: 20),
        );
      }),
    );
  }
}
