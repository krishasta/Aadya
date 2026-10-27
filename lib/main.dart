import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'services/ble_service.dart';
import 'services/mqtt_service.dart';
import 'services/theme_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Theme Service singleton
  await ThemeService.instance.init();
  // Initialize BLE Service singleton
  await BleService.instance.init();
  // Initialize MQTT Service singleton
  await MqttService.instance.init();

  runApp(const AadhyaBleApp());
}

class AadhyaBleApp extends StatelessWidget {
  const AadhyaBleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeService.instance,
      builder: (context, _) {
        final isDark = ThemeService.instance.isDark;

        // Dynamic system UI overlay update for status & nav bar
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarColor: isDark ? AppTheme.darkBg : AppTheme.bgLight,
            systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          ),
        );

        return MaterialApp(
          title: 'Aadhya',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeService.instance.themeMode,
          home: const HomeScreen(),
        );
      },
    );
  }
}
