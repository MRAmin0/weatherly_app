# ☁️ Weatherly - Optimized Flutter Weather Application

This is a Flutter project designed to display weather information with city search capabilities and responsive, animated backgrounds (rain and snow). This version has been refactored based on the Provider architecture, focusing heavily on performance improvement and secret key security.

## 🚀 Key Features
- Clean Architecture: Complete separation of networking and state management (Business Logic) into the WeatherStore class using the provider package.
- Performance Optimization: Heavy rain and snow animations have been converted from multiple widgets to a highly efficient CustomPainter implementation to prevent FPS drops and application sluggishness.
- API Key Security: The API key is isolated from the source code and stored in a local keys.json file (which is tracked by .gitignore).
- Beautiful UI: Modern design utilizing Glassmorphism effects and dynamic animated backgrounds.

## 🔑 Setup and Security Configuration
- To run the project correctly, you must configure your API key and ensure the relevant file is excluded from version control (Git).

## 1. Install Dependencies
1. Open your pubspec.yaml file and ensure the following dependencies are included:

```bash
dependencies:
  flutter:
    sdk: flutter
  http: ^1.1.0
  provider: ^6.0.5          # For state management
  simple_animations: ^5.0.0 # For background animations
  # ... other packages
```
After adding them, run the command:

```bash
flutter pub get
```

## 2. Configure Assets in pubspec.yaml
- To allow the application to read the secret key file, you must add it to the assets section:
```bash
flutter:
  uses-material-design: true
  assets:
    - keys.json  # **IMPORTANT:** This line must be present
```

## 3. API Key Setup (Security Critical)
1. Create keys.json: Create a new file named keys.json in the root directory of your project (next to pubspec.yaml).
2. Insert the Key: Place your OpenWeatherMap API key inside:
```json
{
    "openweathermap_api_key": "YOUR_ACTUAL_API_KEY_HERE"
}
```
## ⚙️ Code Structure
- The project is divided into four main files inside the lib folder to adhere to SOLID principles and Separation of Concerns

## 🛠️ How to Run the Project

1. Complete the Setup and Security Configuration steps above.
2. Open your terminal in the project root directory.
3. Run the application on your desired device or emulator:
```bash
flutter run
```

## 🤝 Contributing

- Contributions are always welcome! If you find a bug, have a feature request, or want to contribute code, please follow these steps:

1. Fork the repository.
2. Create a new branch (git checkout -b feature/AmazingFeature).
3. Commit your changes (git commit -m 'Add some AmazingFeature').
4. Push to the branch (git push origin feature/AmazingFeature).
5. Open a Pull Request.

## 📝 License
This project is licensed under the MIT License - see the LICENSE file for details (Note: you should create a separate LICENSE file in your repository).

## 🙏 Acknowledgements

- Weather Data: Provided by the OpenWeatherMap<a>https://openweathermap.org/api</a> API.
- State Management: The excellent Provider package by Remi Rousselet.