import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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


  WeatherStore() {
    _fetchWeatherAndForecast(cityName: _location);
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  WeatherType _stringToWeatherType(String weatherMain) {
    switch (weatherMain) {
      case 'Clear': return WeatherType.clear;
      case 'Clouds': return WeatherType.clouds;
      case 'Rain': return WeatherType.rain;
      case 'Snow': return WeatherType.snow;
      case 'Drizzle': return WeatherType.drizzle;
      case 'Thunderstorm': return WeatherType.thunderstorm;
      default: return WeatherType.unknown;
    }
  }

  Future<void> _fetchWeatherAndForecast(
      {String? cityName, double? lat, double? lon}) async {
    if (_apiKey == 'API_KEY_NOT_FOUND') {
      _errorMessage = 'API Key is missing. Check keys.json.';
      _setLoading(false);
      return;
    }

    _setLoading(true);
    _errorMessage = null;

    String weatherUrl;
    String forecastUrl;

    if (lat != null && lon != null) {
      weatherUrl =
          'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$_apiKey&units=metric';
      forecastUrl =
          'https://api.openweathermap.org/data/2.5/forecast?lat=$lat&lon=$lon&appid=$_apiKey&units=metric';
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
        final weatherData = await compute(json.decode, weatherResponse.body);
        final forecastData = await compute(json.decode, forecastResponse.body);

        final dailyForecast = (forecastData['list'] as List)
            .where((item) => item['dt_txt'].toString().contains('12:00:00'))
            .toList();

        _location = weatherData['name'] ?? cityName ?? 'Unknown';
        _temperature = weatherData['main']['temp'];
        _weatherType = _stringToWeatherType(weatherData['weather'][0]['main']);
        _forecast = dailyForecast;
        _currentLat = weatherData['coord']['lat'];
        _currentLon = weatherData['coord']['lon'];
        _suggestions = [];

      } else {
        _errorMessage = 'City not found or server error (${weatherResponse.statusCode}).';
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
        'http://api.openweathermap.org/geo/1.0/direct?q=$encodedQuery&limit=5&appid=$_apiKey';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = await compute(json.decode, response.body) as List;
        _suggestions = data.cast<Map<String, dynamic>>();
        notifyListeners();
      }
    } catch (e) { /* خطا را نادیده می‌گیریم */ }
  }

  void selectCity(Map<String, dynamic> cityData) {
    final lat = cityData['lat'];
    final lon = cityData['lon'];
    final name = cityData['name'];

    _location = name;
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