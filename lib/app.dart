import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';

// Pages
// import 'screens/driver/driver_signup_page.dart'; // TODO: migrate if needed
// import 'screens/client/client_signup_page.dart'; // TODO: migrate if needed

/// Provider that holds the current [ThemeMode] of the application.
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

/// Provider that holds the current locale selected by the user. If null
/// then the system locale will be used. Default is Arabic.
final localeProvider = StateProvider<Locale>((ref) => const Locale('ar'));

/// WadiniSafeApp sets up the core configuration such as themes, localization,
/// and routing. It reads state from providers to reflect user settings.
class WadiniSafeApp extends ConsumerWidget {
  const WadiniSafeApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final goRouter = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'WadiniSafe',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      locale: locale,
      routerConfig: goRouter,
      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
