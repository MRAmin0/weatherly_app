import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'config_reader.dart';

enum WeatherType { rain, snow, clear, clouds, drizzle, thunderstorm, unknown }

class WeatherStore extends ChangeNotifier {
  // خواندن کلید API از ConfigReader به جای Hardcode
  final String _apiKey = ConfigReader.getOpenWeatherApiKey();

  // 1. متغیرهای وضعیت
  String _location = 'Tehran';
  double? _temperature;
  WeatherType _weatherType = WeatherType.unknown;
  bool _isLoading = false;
  List<Map<String, dynamic>> _suggestions = [];
  List<dynamic> _forecast = [];
  double? _currentLat;
  double? _currentLon;
  Timer? _debounce;
  String? _errorMessage;

  // Getterها
  String get location => _location;
  double? get temperature => _temperature;
  WeatherType get weatherType => _weatherType;
  bool get isLoading => _isLoading;
  List<Map<String, dynamic>> get suggestions => _suggestions;
  List<dynamic> get forecast => _forecast;
  String? get errorMessage => _errorMessage;

  bool _isPersian(String s) => RegExp(r'[اآءؤئپچژکگ‌ی]').hasMatch(s);

  String _normalize(String s) {
    return s
        .trim()
        .toLowerCase()
        .replaceAll('ي', 'ی')
        .replaceAll('ك', 'ک')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  String _composeCityLabel(Map<String, dynamic> c) {
    final name = (c['local_names']?['fa'] ?? c['name'] ?? '').toString();
    final country = (c['country'] ?? '').toString();
    final state = (c['state'] ?? '').toString();
    return [
      name,
      if (state.isNotEmpty) state,
      if (country.isNotEmpty) country,
    ].join(', ');
  }

  // مرتب‌سازی گزینه‌های ژئوکد؛ ورودی فارسی → ایران اولویت، تطابق دقیق اسم، جمعیت بیشتر
  Map<String, dynamic>? _pickBestCandidate(List<dynamic> items, String query) {
    if (items.isEmpty) return null;
    final qNorm = _normalize(query);

    int scoreOf(Map<String, dynamic> c) {
      int s = 0;
      final country = (c['country'] ?? '').toString();
      final nameFa = (c['local_names']?['fa'] ?? '').toString();
      final name = (c['name'] ?? '').toString();
      final pop = (c['population'] ?? 0) as int? ?? 0;

      if (_isPersian(query) && country == 'IR') s += 5;
      if (_normalize(nameFa) == qNorm || _normalize(name) == qNorm) s += 4;
      if (country == 'IR') s += 2;
      s += (pop ~/ 100000); // هر 100هزار نفر +1

      return s;
    }

    items.sort(
      (a, b) =>
          scoreOf(b as Map<String, dynamic>) -
          scoreOf(a as Map<String, dynamic>),
    );
    return items.first as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> _resolveCityToCoord(String query) async {
    final encoded = Uri.encodeComponent(query);
    final lang = _isPersian(query) ? 'fa' : 'en';
    final url =
        'https://api.openweathermap.org/geo/1.0/direct?q=$encoded&limit=5&appid=$_apiKey&lang=$lang';

    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = await compute(json.decode, res.body) as List<dynamic>;
        final best = _pickBestCandidate(data, query);
        return best; // شامل name/local_names/lat/lon/country/state/...
      }
    } catch (_) {}
    return null;
  }

  WeatherStore() {
    _fetchWeatherAndForecast(cityName: _location);
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  WeatherType _stringToWeatherType(String weatherMain) {
    switch (weatherMain) {
      case 'Clear':
        return WeatherType.clear;
      case 'Clouds':
        return WeatherType.clouds;
      case 'Rain':
        return WeatherType.rain;
      case 'Snow':
        return WeatherType.snow;
      case 'Drizzle':
        return WeatherType.drizzle;
      case 'Thunderstorm':
        return WeatherType.thunderstorm;
      default:
        return WeatherType.unknown;
    }
  }

  Future<void> _fetchWeatherAndForecast({
    String? cityName,
    double? lat,
    double? lon,
  }) async {
    if (_apiKey == 'API_KEY_NOT_FOUND') {
      _errorMessage = 'API Key is missing. Check keys.json.';
      _setLoading(false);
      return;
    }

    _setLoading(true);
    _errorMessage = null;

    double? useLat = lat;
    double? useLon = lon;
    String? resolvedName;

    // اگر مختصات نداریم ولی اسم شهر داریم، اول ژئوکد می‌کنیم
    if ((useLat == null || useLon == null) &&
        cityName != null &&
        cityName.trim().isNotEmpty) {
      final resolved = await _resolveCityToCoord(cityName.trim());
      if (resolved != null) {
        useLat = (resolved['lat'] as num?)?.toDouble();
        useLon = (resolved['lon'] as num?)?.toDouble();
        resolvedName = _composeCityLabel(resolved);
      }
    }

    String weatherUrl;
    String forecastUrl;

    if (useLat != null && useLon != null) {
      weatherUrl =
          'https://api.openweathermap.org/data/2.5/weather?lat=$useLat&lon=$useLon&appid=$_apiKey&units=metric';
      forecastUrl =
          'https://api.openweathermap.org/data/2.5/forecast?lat=$useLat&lon=$useLon&appid=$_apiKey&units=metric';
    } else if (cityName != null) {
      weatherUrl =
          'https://api.openweathermap.org/data/2.5/weather?q=${Uri.encodeComponent(cityName)}&appid=$_apiKey&units=metric';
      forecastUrl =
          'https://api.openweathermap.org/data/2.5/forecast?q=${Uri.encodeComponent(cityName)}&appid=$_apiKey&units=metric';
    } else {
      _setLoading(false);
      return;
    }

    try {
      final weatherResponse = await http.get(Uri.parse(weatherUrl));
      final forecastResponse = await http.get(Uri.parse(forecastUrl));

      if (weatherResponse.statusCode == 200 &&
          forecastResponse.statusCode == 200) {
        // استفاده از compute برای JSON Decoding (بهبود پرفورمنس در داده‌های بزرگتر)
        final weatherData =
            await compute(json.decode, weatherResponse.body)
                as Map<String, dynamic>;
        final forecastData =
            await compute(json.decode, forecastResponse.body)
                as Map<String, dynamic>;

        final dailyForecast = (forecastData['list'] as List)
            .where((item) => item['dt_txt'].toString().contains('12:00:00'))
            .toList();

        // استفاده از resolvedName اگر موجود بود، در غیر این صورت از پاسخ API
        if (resolvedName != null) {
          _location = resolvedName;
        } else {
          final apiName = (weatherData['name'] ?? '').toString();
          final apiCountry = ((weatherData['sys'] ?? {})['country'] ?? '')
              .toString();
          if (apiName.isNotEmpty || apiCountry.isNotEmpty) {
            _location = _composeCityLabel({
              'name': apiName,
              'country': apiCountry,
            });
          } else {
            _location = cityName ?? 'Unknown';
          }
        }

        _temperature = (weatherData['main']?['temp'] as num?)?.toDouble();
        _weatherType = _stringToWeatherType(
          (weatherData['weather']?[0]?['main'] ?? '').toString(),
        );
        _forecast = dailyForecast;
        _currentLat =
            (weatherData['coord']?['lat'] as num?)?.toDouble() ?? useLat;
        _currentLon =
            (weatherData['coord']?['lon'] as num?)?.toDouble() ?? useLon;
        _suggestions = [];
      } else {
        _errorMessage =
            'City not found or server error (${weatherResponse.statusCode}).';
        _temperature = null;
        _forecast = [];
      }
    } catch (e) {
      _errorMessage = 'Failed to load data. Check network connection.';
    } finally {
      _setLoading(false);
    }
  }

  void onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.length > 2) {
        _fetchCitySuggestions(query);
      } else {
        _suggestions = [];
        notifyListeners();
      }
    });
  }

  Future<void> _fetchCitySuggestions(String query) async {
    if (_apiKey == 'API_KEY_NOT_FOUND') return;
    final encodedQuery = Uri.encodeComponent(query);
    final url =
        'https://api.openweathermap.org/geo/1.0/direct?q=$encodedQuery&limit=5&appid=$_apiKey';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = await compute(json.decode, response.body) as List;
        _suggestions = data.cast<Map<String, dynamic>>();
        notifyListeners();
      }
    } catch (e) {
      /* خطا را نادیده می‌گیریم */
    }
  }

  void selectCity(Map<String, dynamic> cityData) {
    final lat = (cityData['lat'] as num?)?.toDouble();
    final lon = (cityData['lon'] as num?)?.toDouble();

    // استفاده از _composeCityLabel برای نمایش بهتر نام شهر
    _location = _composeCityLabel(cityData);
    _suggestions = [];
    notifyListeners();

    _fetchWeatherAndForecast(lat: lat, lon: lon);
  }

  Future<void> handleRefresh() async {
    if (_currentLat != null && _currentLon != null) {
      await _fetchWeatherAndForecast(lat: _currentLat, lon: _currentLon);
    } else {
      await _fetchWeatherAndForecast(cityName: _location);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
