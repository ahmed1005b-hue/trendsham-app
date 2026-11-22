import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/theme.dart';
import 'l10n/app_localizations.dart';
import 'providers/app_settings_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'services/push_service.dart';
import 'utils/notification_router.dart';
import 'utils/role_router.dart';
import 'widgets/consent_banner.dart';
import 'theme/theme_switcher.dart';
import 'services/app_update.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final settings = AppSettingsProvider(preferences: preferences);
  final themeController = ThemeController(prefs: preferences);
  await settings.load();
  // الترجمات قبل أول إطار: لا تظهر الواجهة لحظةً بالعربية ثم تتبدّل
  await L10nCatalog.load();
  await PushService.instance.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: themeController),
      ],
      child: const TrendShamApp(),
    ),
  );
}

class TrendShamApp extends StatelessWidget {
  const TrendShamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<AppSettingsProvider, ThemeController>(
      builder: (context, settings, themeController, _) {
        return MaterialApp(
          navigatorKey: NotificationRouter.navigatorKey,
          scaffoldMessengerKey: NotificationRouter.messengerKey,
          onGenerateTitle: (context) =>
              AppLocalizations.of(context).translate('تريندشام'),
          debugShowCheckedModeBanner: false,
          locale: settings.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            final themed = Theme(
              data: AppTheme.forLanguage(Theme.of(context),
                  Localizations.localeOf(context).languageCode),
              child: child!,
            );
            return Stack(
              children: [
                RepaintBoundary(
                  child: themed,
                ),
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ConsentBanner(),
                ),
              ],
            );
          },
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeController.themeMode,
          home: const AppUpdateGate(child: RootRouter()),
        );
      },
    );
  }
}

class RootRouter extends StatelessWidget {
  const RootRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isLoading) return const SplashScreen();
        if (auth.isLoggedIn) return roleHomeScreen(auth.user!.role);
        return const LoginScreen();
      },
    );
  }
}
