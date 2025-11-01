import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'weather_store.dart';
import 'settings_drawer.dart';

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
          drawer: SettingsDrawer(
            store: store,
            currentThemeMode: widget.currentThemeMode,
            onThemeChanged: widget.onThemeChanged,
          ),
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
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[ء-يآ-یa-zA-Z\s]'),
                          ),
                        ],
                        textAlign: TextAlign.right,
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
        if (store.showAirQuality) ...[
          const SizedBox(height: 30),
          _buildAirQualitySection(store),
        ],
        const SizedBox(height: 40),
        if (store.forecast.isNotEmpty) _buildForecastSection(store),
        const SizedBox(height: 30),
        if (store.hourlyForecast.isNotEmpty) _buildHourlySection(store),
      ],
    );
  }

  Widget _buildHourlySection(WeatherStore store) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "دمای ساعتی",
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
            itemCount: store.hourlyForecast.length,
            itemBuilder: (context, index) {
              final hour = store.hourlyForecast[index];
              final date = DateTime.parse(hour['dt_txt']);
              final rawTemp = (hour['main']['temp'] as num).toDouble();
              final displayedTemp = store.useCelsius
                  ? rawTemp
                  : (rawTemp * 9 / 5) + 32;
              final temp = displayedTemp.toStringAsFixed(0);
              final main = hour['weather'][0]['main'] as String;
              final icon = _getWeatherIcon(main);

              return GlassmorphicContainer(
                child: SizedBox(
                  width: 80,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "${date.hour}:00",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Icon(icon, color: Colors.orangeAccent),
                      const SizedBox(height: 8),
                      Text(
                        "$temp°",
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

  Widget _buildAirQualitySection(WeatherStore store) {
    final aqi = store.airQualityIndex ?? 0;
    String status;
    Color color;

    switch (aqi) {
      case 1:
        status = 'خوب';
        color = Colors.greenAccent;
        break;
      case 2:
        status = 'متوسط';
        color = Colors.yellowAccent;
        break;
      case 3:
        status = 'ناسالم برای گروه‌های حساس';
        color = Colors.orangeAccent;
        break;
      case 4:
        status = 'ناسالم';
        color = Colors.redAccent;
        break;
      case 5:
        status = 'خیلی ناسالم';
        color = Colors.purpleAccent;
        break;
      default:
        status = 'نامشخص';
        color = Colors.grey;
    }

    return GlassmorphicContainer(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'کیفیت هوا',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'شاخص: $aqi',
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                Text(
                  status,
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Icon(Icons.air_rounded, color: color, size: 42),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentWeatherSection(WeatherStore store) {
    final tempC = store.temperature;
    final temp = store.useCelsius
        ? tempC
        : (tempC != null ? (tempC * 9 / 5) + 32 : null);

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
          '${temp?.toStringAsFixed(1) ?? '--'}°',
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
              final rawTemp = (day['main']['temp'] as num).toDouble();
              final displayedTemp = store.useCelsius
                  ? rawTemp
                  : (rawTemp * 9 / 5) + 32;
              final temp = displayedTemp.toStringAsFixed(0);
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
}
