import 'package:flutter/material.dart';
import 'weather_store.dart';

class SettingsDrawer extends StatelessWidget {
  final WeatherStore store;
  final ThemeMode currentThemeMode;
  final Function(ThemeMode) onThemeChanged;

  const SettingsDrawer({
    super.key,
    required this.store,
    required this.currentThemeMode,
    required this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
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
                  selected: {currentThemeMode},
                  onSelectionChanged: (selection) {
                    if (selection.isNotEmpty) {
                      onThemeChanged(selection.first);
                    }
                  },
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('نمایش دمای ساعتی'),
                  value: store.showHourly,
                  onChanged: (val) {
                    store.updatePreference('showHourly', val);
                  },
                ),
                SwitchListTile(
                  title: const Text('نمایش آلودگی هوا'),
                  value: store.showAirQuality,
                  onChanged: (val) {
                    store.updatePreference('showAirQuality', val);
                  },
                ),
                SwitchListTile(
                  title: const Text('واحد دما: سلسیوس / فارنهایت'),
                  value: store.useCelsius,
                  onChanged: (val) {
                    store.updatePreference('useCelsius', val);
                  },
                ),
                ListTile(
                  title: const Text('شهر پیش‌فرض'),
                  subtitle: Text(store.defaultCity),
                  trailing: const Icon(Icons.edit),
                  onTap: () async {
                    final controller = TextEditingController(
                      text: store.defaultCity,
                    );
                    final result = await showDialog<String>(
                      context: context,
                      builder: (ctx) {
                        return AlertDialog(
                          title: const Text('ویرایش شهر پیش‌فرض'),
                          content: TextField(controller: controller),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('انصراف'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(ctx, controller.text.trim());
                              },
                              child: const Text('ذخیره'),
                            ),
                          ],
                        );
                      },
                    );

                    if (result != null && result.isNotEmpty) {
                      await store.updatePreference('defaultCity', result);
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
