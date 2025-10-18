import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'weather_store.dart';

// ----------------------------------------------------------------------
// ویجت اصلی UI
// ----------------------------------------------------------------------

class WeatherScreen extends StatefulWidget {
  final ThemeMode currentThemeMode;
  final Function(ThemeMode) onThemeChanged;

  const WeatherScreen({
    super.key,
    required this.currentThemeMode,
    required this.onThemeChanged,
  });

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final TextEditingController _cityController = TextEditingController();

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Consumer برای گوش دادن به تغییرات وضعیت (Store)
    return Consumer<WeatherStore>(
      builder: (context, store, child) {
        return Scaffold(
          drawer: _buildSettingsDrawer(context, store),
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: const Text('Weatherly'),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: Stack(
            children: [
              // 1. نمایش پس‌زمینه انیمیشنی بهینه شده
              WeatherBackground(weatherType: store.weatherType),

              // 2. RefreshIndicator
              RefreshIndicator(
                onRefresh: store.handleRefresh,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: ListView(
                      // برای فعال بودن کشیدن صفحه حتی با محتوای کم
                      physics: const AlwaysScrollableScrollPhysics(), 
                      children: [
                        const SizedBox(height: 16),
                        _buildSearchSection(context, store),
                        const SizedBox(height: 40),
                        if (store.isLoading)
                          const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.white70))
                        else
                          _buildWeatherContent(store),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // -------------------------
  // ویجت‌های کمکی UI
  // -------------------------

  Widget _buildWeatherContent(WeatherStore store) {
    if (store.errorMessage != null) {
      return Center(
          child: Padding(
        padding: const EdgeInsets.only(top: 150),
        child: Text(store.errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold)),
      ));
    }
    return Column(
      children: [
        _buildCurrentWeatherSection(store),
        const SizedBox(height: 40),
        if (store.forecast.isNotEmpty) _buildForecastSection(store),
      ],
    );
  }

  Widget _buildSearchSection(BuildContext context, WeatherStore store) {
    return Column(
      children: [
        GlassmorphicContainer(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cityController,
                    style: const TextStyle(color: Colors.white),
                    maxLength: 15,
                    onChanged: store.onSearchChanged,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                    ],
                    decoration: const InputDecoration(
                      hintText: 'e.g., London',
                      hintStyle: TextStyle(color: Colors.white54),
                      border: InputBorder.none,
                      counterText: "",
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search, color: Colors.white),
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    if (store.suggestions.isNotEmpty) {
                      store.selectCity(store.suggestions.first);
                    } else if (_cityController.text.isNotEmpty) {
                      store.fetchWeatherAndForecast(
                          cityName: _cityController.text);
                    }
                    _cityController.clear();
                  },
                ),
              ],
            ),
          ),
        ),
        if (store.suggestions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: GlassmorphicContainer(
              child: SizedBox(
                height: 200,
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: store.suggestions.length,
                  itemBuilder: (context, index) {
                    final suggestion = store.suggestions[index];
                    final name = suggestion['name'] ?? 'Unknown';
                    final country = suggestion['country'] ?? '';
                    final state = suggestion['state'] ?? '';
                    String subtitle = country;
                    if (state.isNotEmpty && state != name) {
                      subtitle = '$state, $country';
                    }
                    return ListTile(
                      title: Text(name,
                          style: const TextStyle(color: Colors.white)),
                      subtitle: Text(subtitle,
                          style: const TextStyle(color: Colors.white70)),
                      onTap: () {
                        store.selectCity(suggestion);
                        _cityController.clear();
                        FocusScope.of(context).unfocus();
                      },
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCurrentWeatherSection(WeatherStore store) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(store.location,
            style: const TextStyle(
                fontSize: 42, fontWeight: FontWeight.bold, color: Colors.white),
            textAlign: TextAlign.center),
        const SizedBox(height: 20),
        Text('${store.temperature?.toStringAsFixed(1) ?? '--'}°C',
            style: const TextStyle(
                fontSize: 64, fontWeight: FontWeight.w200, color: Colors.white)),
        const SizedBox(height: 20),
        Text(store.weatherType.name.toUpperCase(),
            style: const TextStyle(fontSize: 26, color: Colors.white70)),
      ],
    );
  }

  Widget _buildForecastSection(WeatherStore store) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("5-Day Forecast",
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        const SizedBox(height: 10),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: store.forecast.length,
            itemBuilder: (context, index) {
              final day = store.forecast[index];
              final date = DateTime.parse(day['dt_txt']);
              // بهینه‌سازی شده برای نمایش فارسی (اختیاری)
              final dayOfWeek = ['دوشنبه', 'سه شنبه', 'چهارشنبه', 'پنجشنبه', 'جمعه', 'شنبه', 'یکشنبه'][date.weekday - 1]; 
              final temp = day['main']['temp'].toStringAsFixed(0);
              final weatherMain = day['weather'][0]['main'];
              final icon = _getWeatherIcon(weatherMain);

              return GlassmorphicContainer(
                child: SizedBox(
                  width: 80,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text(dayOfWeek,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.white)),
                      Icon(icon, color: Colors.orangeAccent),
                      Text('$temp°C',
                          style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  IconData _getWeatherIcon(String weather) {
    switch (weather) {
      case 'Clear':
        return Icons.wb_sunny;
      case 'Clouds':
        return Icons.cloud;
      case 'Rain':
      case 'Drizzle':
      case 'Thunderstorm':
        return Icons.umbrella;
      case 'Snow':
        return Icons.ac_unit;
      default:
        return Icons.cloud_queue;
    }
  }
  
  Widget _buildSettingsDrawer(BuildContext context, WeatherStore store) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue),
            child: Text('Settings', style: TextStyle(color: Colors.white, fontSize: 24)),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Theme', style: Theme.of(context).textTheme.titleLarge),
                const Divider(),
                RadioListTile<ThemeMode>(
                  title: const Text('System Default'),
                  value: ThemeMode.system,
                  groupValue: widget.currentThemeMode,
                  onChanged: (v) => v != null ? widget.onThemeChanged(v) : null,
                ),
                RadioListTile<ThemeMode>(
                  title: const Text('Light'),
                  value: ThemeMode.light,
                  groupValue: widget.currentThemeMode,
                  onChanged: (v) => v != null ? widget.onThemeChanged(v) : null,
                ),
                RadioListTile<ThemeMode>(
                  title: const Text('Dark'),
                  value: ThemeMode.dark,
                  groupValue: widget.currentThemeMode,
                  onChanged: (v) => v != null ? widget.onThemeChanged(v) : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------
// ویجت‌های استاتیک و Glassmorphism
// ----------------------------------------------------------------------

class GlassmorphicContainer extends StatelessWidget {
  final Widget child;
  const GlassmorphicContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15.0),
      child: BackdropFilter(
        // استفاده از افکت Blur برای Glassmorphism
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          margin: const EdgeInsets.only(right: 10, bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(15.0),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// ویجت‌های پس‌زمینه و انیمیشن بهینه‌شده با CustomPainter
// ----------------------------------------------------------------------

class WeatherBackground extends StatelessWidget {
  final WeatherType weatherType;
  const WeatherBackground({super.key, required this.weatherType});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    switch (weatherType) {
      case WeatherType.rain:
      case WeatherType.drizzle:
      case WeatherType.thunderstorm:
        return const RainAnimation(); // انیمیشن بهینه شده
      case WeatherType.snow:
        return const SnowAnimation(); // انیمیشن بهینه شده
      case WeatherType.clear:
      case WeatherType.unknown:
        return SunnyBackground(isDarkMode: isDarkMode);
      case WeatherType.clouds:
        return CloudyBackground(isDarkMode: isDarkMode);
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

// --- انیمیشن باران بهینه شده با CustomPainter ---

class RainAnimation extends StatelessWidget {
  const RainAnimation({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF283E51), Color(0xFF0A2342)],
        ),
      ),
      child: const AnimatedRain(), // فقط یک ویجت متحرک به جای ۱۰۰ ویجت
    );
  }
}

class AnimatedRain extends StatefulWidget {
  const AnimatedRain({super.key});
  @override
  State<AnimatedRain> createState() => _AnimatedRainState();
}

class _AnimatedRainState extends State<AnimatedRain>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<RainDropData> _drops = [];
  static const int _numberOfDrops = 100;

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < _numberOfDrops; i++) {
      _drops.add(RainDropData());
    }
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _controller.addListener(() {
      // فقط setState برای بازخوانی CustomPainter
      setState(() {
        for (var drop in _drops) {
          drop.update();
        }
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: RainPainter(_drops),
      child: Container(),
    );
  }
}

class RainDropData {
  late double x, y, speed, length;
  final Random _rand = Random();

  RainDropData() {
    _reset();
  }

  void _reset() {
    x = _rand.nextDouble();
    y = -_rand.nextDouble() * 0.5;
    speed = _rand.nextDouble() * 0.02 + 0.01;
    length = _rand.nextDouble() * 10 + 10;
  }

  void update() {
    y += speed;
    if (y > 1.0) _reset();
  }
}

class RainPainter extends CustomPainter {
  final List<RainDropData> drops;
  final Paint _paint = Paint()
    ..color = Colors.blue.shade100
    ..strokeWidth = 1.5;

  RainPainter(this.drops);

  @override
  void paint(Canvas canvas, Size size) {
    for (var drop in drops) {
      final startX = drop.x * size.width;
      final startY = drop.y * size.height;
      final endY = startY + drop.length;

      canvas.drawLine(
        Offset(startX, startY),
        Offset(startX, endY),
        _paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant RainPainter oldDelegate) => true;
}

// --- انیمیشن برف بهینه شده با CustomPainter ---

class SnowAnimation extends StatelessWidget {
  const SnowAnimation({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3a6ea5), Color(0xFF22333b)],
        ),
      ),
      child: const AnimatedSnow(),
    );
  }
}

class AnimatedSnow extends StatefulWidget {
  const AnimatedSnow({super.key});
  @override
  State<AnimatedSnow> createState() => _AnimatedSnowState();
}

class _AnimatedSnowState extends State<AnimatedSnow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<SnowFlakeData> _flakes = [];
  static const int _numberOfFlakes = 50;

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < _numberOfFlakes; i++) {
      _flakes.add(SnowFlakeData());
    }
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();

    _controller.addListener(() {
      setState(() {
        for (var flake in _flakes) {
          flake.update();
        }
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: SnowPainter(_flakes),
      child: Container(),
    );
  }
}

class SnowFlakeData {
  late double x, y, speed, size;
  final Random _rand = Random();

  SnowFlakeData() {
    _reset();
  }

  void _reset() {
    x = _rand.nextDouble();
    y = -_rand.nextDouble() * 0.5;
    speed = _rand.nextDouble() * 0.005 + 0.002;
    size = _rand.nextDouble() * 6 + 4;
  }

  void update() {
    y += speed;
    // حرکت افقی سینوسی برای شبیه سازی باد
    x += sin(y * 10) * 0.001; 
    if (y > 1.0) _reset();
  }
}

class SnowPainter extends CustomPainter {
  final List<SnowFlakeData> flakes;
  final Paint _paint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.fill;

  SnowPainter(this.flakes);

  @override
  void paint(Canvas canvas, Size size) {
    for (var flake in flakes) {
      final centerX = flake.x * size.width;
      final centerY = flake.y * size.height;

      // ترسیم دایره به جای ویجت آیکون (CustomPainter کارآمدتر است)
      canvas.drawCircle(Offset(centerX, centerY), flake.size / 3, _paint);
    }
  }

  @override
  bool shouldRepaint(covariant SnowPainter oldDelegate) => true;
}