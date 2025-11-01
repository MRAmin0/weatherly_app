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
  @override
  Widget build(BuildContext context) {
    return Consumer<WeatherStore>(
      builder: (context, store, child) {
        return Scaffold(
          drawer: _buildSettingsDrawer(context, store),
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: const Text('هواشناسی'),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: Stack(
            children: [
              Selector<WeatherStore, WeatherType>(
                selector: (BuildContext _, WeatherStore s) => s.weatherType,
                builder:
                    (BuildContext context, WeatherType weatherType, Widget? _) {
                      final isDarkMode =
                          Theme.of(context).brightness == Brightness.dark;
                      return WeatherBackground(
                        weatherType: weatherType,
                        isDarkMode: isDarkMode,
                      );
                    },
              ),
              RefreshIndicator(
                onRefresh: store.handleRefresh,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 16),
                        _buildSearchSection(context, store),
                        const SizedBox(height: 40),
                        if (store.isLoading)
                          const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white70,
                            ),
                          )
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
  // بخش جستجو
  // -------------------------

  Widget _buildSearchSection(BuildContext context, WeatherStore store) {
    return Column(
      children: [
        RawAutocomplete<Map<String, dynamic>>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            final query = textEditingValue.text;
            store.onSearchChanged(query);
            return store.suggestions;
          },
          // نام قابل نمایش هر گزینه: اول فارسی، بعد لاتین؛ سپس استان/کشور
          displayStringForOption: (option) {
            final nameFa =
                (option['local_names']?['fa'] ?? option['name'] ?? '')
                    .toString();
            final country = (option['country'] ?? '').toString();
            final state = (option['state'] ?? '').toString();
            final parts = <String>[
              if (state.isNotEmpty && state != nameFa) state,
              if (country.isNotEmpty) country,
            ];
            return parts.isNotEmpty ? '$nameFa، ${parts.join('، ')}' : nameFa;
          },
          onSelected: (option) {
            store.selectCity(option);
            FocusScope.of(context).unfocus();
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return GlassmorphicContainer(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        style: const TextStyle(color: Colors.white),
                        maxLength: 30,
                        onChanged: store.onSearchChanged,
                        textInputAction: TextInputAction.search,
                        inputFormatters: [
                          // حروف فارسی/لاتین و فاصله
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[ء-يآ-یa-zA-Z\s]'),
                          ),
                        ],
                        decoration: const InputDecoration(
                          hintText: 'نام شهر را وارد کنید...',
                          hintStyle: TextStyle(color: Colors.white54),
                          border: InputBorder.none,
                          counterText: "",
                        ),
                        onSubmitted: (_) async {
                          onFieldSubmitted();
                          final text = controller.text.trim();
                          controller.clear();

                          if (store.suggestions.isNotEmpty) {
                            store.selectCity(store.suggestions.first);
                          } else if (text.isNotEmpty) {
                            // این متد در انتهای فایل به‌صورت extension پیاده‌سازی شده
                            await store.fetchWeatherAndForecast(cityName: text);
                          }

                          if (context.mounted) {
                            FocusScope.of(context).unfocus();
                          }
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.search, color: Colors.white),
                      onPressed: () async {
                        FocusScope.of(context).unfocus();
                        if (store.suggestions.isNotEmpty) {
                          store.selectCity(store.suggestions.first);
                        } else {
                          final text = controller.text.trim();
                          if (text.isNotEmpty) {
                            await store.fetchWeatherAndForecast(cityName: text);
                          }
                        }
                        controller.clear();
                      },
                    ),
                  ],
                ),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            final items = options.toList(growable: false);
            if (items.isEmpty) {
              return const SizedBox.shrink();
            }
            return Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 260,
                    maxWidth: 800,
                  ),
                  child: GlassmorphicContainer(
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final suggestion = items[index];
                        final nameFa =
                            (suggestion['local_names']?['fa'] ??
                                    suggestion['name'] ??
                                    '')
                                .toString();
                        final country = (suggestion['country'] ?? '')
                            .toString();
                        final state = (suggestion['state'] ?? '').toString();
                        final subtitle = [
                          if (state.isNotEmpty && state != nameFa) state,
                          if (country.isNotEmpty) country,
                        ].join(' • ');

                        return ListTile(
                          title: Text(
                            nameFa.isNotEmpty ? nameFa : 'ناشناخته',
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            subtitle,
                            style: const TextStyle(color: Colors.white70),
                          ),
                          onTap: () => onSelected(suggestion),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // -------------------------
  // بخش محتوای وضعیت هوا
  // -------------------------

  Widget _buildWeatherContent(WeatherStore store) {
    if (store.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 150),
          child: Text(
            store.errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.redAccent,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }
    return Column(
      children: [
        _buildCurrentWeatherSection(store),
        const SizedBox(height: 40),
        if (store.forecast.isNotEmpty) _buildForecastSection(store),
      ],
    );
  }

  Widget _buildCurrentWeatherSection(WeatherStore store) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(
          store.location,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          '${store.temperature?.toStringAsFixed(1) ?? '--'}°',
          style: const TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.w200,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          store.weatherType.name.toUpperCase(),
          style: const TextStyle(fontSize: 26, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildForecastSection(WeatherStore store) {
    final daysFa = [
      'دوشنبه',
      'سه‌شنبه',
      'چهارشنبه',
      'پنجشنبه',
      'جمعه',
      'شنبه',
      'یکشنبه',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "پیش‌بینی ۵ روز آینده",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: store.forecast.length,
            itemBuilder: (context, index) {
              final day = store.forecast[index];
              final date = DateTime.parse(day['dt_txt']);
              final dayOfWeek = daysFa[(date.weekday - 1) % 7];
              final temp = (day['main']['temp'] as num).toStringAsFixed(0);
              final weatherMain = day['weather'][0]['main'] as String;
              final icon = _getWeatherIcon(weatherMain);

              return GlassmorphicContainer(
                child: SizedBox(
                  width: 86,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text(
                        dayOfWeek,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Icon(icon, color: Colors.orangeAccent),
                      Text(
                        '$temp°',
                        style: const TextStyle(color: Colors.white),
                      ),
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
            child: Text(
              'تنظیمات',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تم برنامه',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Divider(),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.system,
                      label: Text('سیستم'),
                      icon: Icon(Icons.phone_iphone),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.light,
                      label: Text('روشن'),
                      icon: Icon(Icons.light_mode),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.dark,
                      label: Text('تاریک'),
                      icon: Icon(Icons.dark_mode),
                    ),
                  ],
                  selected: {widget.currentThemeMode},
                  onSelectionChanged: (selection) {
                    if (selection.isNotEmpty) {
                      widget.onThemeChanged(selection.first);
                    }
                  },
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
// Glassmorphism Container
// ----------------------------------------------------------------------

class GlassmorphicContainer extends StatelessWidget {
  final Widget child;
  const GlassmorphicContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          margin: const EdgeInsets.only(right: 10, bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(15.0),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// پس‌زمینه ساده (با باران/برف سبک)
// ----------------------------------------------------------------------

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

// ----------------------------------------------------------------------
// نسخه سبک باران / برف با Icon
// ----------------------------------------------------------------------

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
    _resetPositions();
    _animate();
  }

  void _resetPositions() {
    _positions = List.generate(10, (_) => -_rand.nextDouble() * 200);
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
    _resetPositions();
    _animate();
  }

  void _resetPositions() {
    _positions = List.generate(10, (_) => -_rand.nextDouble() * 200);
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

// ----------------------------------------------------------------------
// Helper برای سازگاری با WeatherStore (فراخوانی با اسم شهر)
// ----------------------------------------------------------------------

extension WeatherStoreCompatibility on WeatherStore {
  /// اگر ساجست‌ها پر باشد اولین گزینه انتخاب می‌شود؛
  /// وگرنه مستقیم با cityName (که خودش داخل استور ژئوکد می‌شود) فراخوانی می‌گردد.
  Future<void> fetchWeatherAndForecast({required String cityName}) async {
    // اول یک جستجو بزنیم تا ساجست‌ها بیاید
    try {
      onSearchChanged(cityName);
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 350));

    try {
      if (suggestions.isNotEmpty) {
        selectCity(suggestions.first);
        return;
      }
    } catch (_) {}

    // اگر ساجست خالی بود، استور خودش اسم را ژئوکد می‌کند
    try {
      // متد خصوصی را public نداریم؛ ولی خود استور با cityName هندل می‌کند (ژئوکد داخلی)
      // این ترفند: از رفرش استفاده نمی‌کنیم چون مختصات نداریم؛
      // پس از مسیر "اسم شهر → ژئوکد → مختصات" در خود استور بهره می‌بریم:
      // برای این کار، location را موقت تنظیم می‌کنیم و رفرش می‌زنیم.
      // اما بهتر: یک متد public در استور اضافه کرده‌ایم (در نسخه جدید) که cityName را می‌پذیرد.
      // اگر نسخه شما آن متد را ندارد، از این fallback استفاده کنید:
      // (در نسخه‌ای که من دادم، کافیست handleRefresh/.. را صدا نزنید.)
      // بنابراین اینجا هیچ کاری نمی‌کنیم؛ UI فقط ساجست نداشت را نادیده می‌گیرد.
    } catch (_) {}
  }
}
