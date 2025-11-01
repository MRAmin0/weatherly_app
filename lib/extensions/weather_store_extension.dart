import '../weather_store.dart';

extension WeatherStoreCompatibility on WeatherStore {
  Future<void> fetchWeatherAndForecast({required String cityName}) async {
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
  }
}
