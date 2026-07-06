import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'models/user_role.dart';
import 'providers/ai_provider.dart';
import 'providers/alert_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/gateway_provider.dart';
import 'providers/theme_provider.dart';
import 'services/maintenance_view_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
  } catch (error) {
    debugPrint('Firebase unavailable, continuing in mock mode: $error');
  }

  await SystemChrome.setPreferredOrientations([]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFFFFFFFF),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()..load()),
        ChangeNotifierProvider(create: (_) => UserRoleController()),
        ChangeNotifierProvider(create: (_) => MaintenanceViewService()),
        ChangeNotifierProvider(
          create: (_) => NotificationService()..initialize(),
        ),
        ChangeNotifierProvider(
          create: (_) => DashboardProvider()..initialize(),
        ),
        ChangeNotifierProxyProvider2<DashboardProvider, NotificationService,
            AiProvider>(
          create: (_) => AiProvider(),
          update: (_, dashboard, notifications, ai) {
            final provider = ai ?? AiProvider();
            provider.attachNotifications(notifications);
            provider.syncFromDashboard(dashboard);
            return provider;
          },
        ),
        ChangeNotifierProxyProvider2<DashboardProvider, NotificationService,
            AlertProvider>(
          create: (_) => AlertProvider(),
          update: (_, dashboard, notifications, alerts) {
            final provider = alerts ?? AlertProvider();
            provider.attach(notifications);
            provider.syncFromDashboard(dashboard);
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<DashboardProvider, GatewayProvider>(
          create: (_) => GatewayProvider(),
          update: (_, dashboard, gateway) {
            final provider = gateway ?? GatewayProvider();
            provider.syncFromDashboard(dashboard);
            return provider;
          },
        ),
      ],
      child: const SmartCityApp(),
    ),
  );
}
