import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get_it/get_it.dart';

import '../../design_system/theme/app_theme.dart';
import '../../design_system/tokens/colors.dart';
import '../localization/app_localizations.dart';
import '../notifications/push_notification_service.dart';
import '../services/settings_service.dart';

import '../../main.dart';

class AcademyMaterialApp extends StatelessWidget {
  final String titleKey;
  final Widget home;
  final GlobalKey<NavigatorState>? navigatorKey;
  final GlobalKey<ScaffoldMessengerState>? scaffoldMessengerKey;

  const AcademyMaterialApp({
    super.key,
    required this.titleKey,
    required this.home,
    this.navigatorKey,
    this.scaffoldMessengerKey,
  });

  @override
  Widget build(BuildContext context) {
    final settingsService = GetIt.instance<SettingsService>();

    return ListenableBuilder(
      listenable: settingsService,
      builder: (context, _) {
        final locale = settingsService.locale;
        final textDirection = locale.languageCode == 'ar'
            ? TextDirection.rtl
            : TextDirection.ltr;

        return MaterialApp(
          scaffoldMessengerKey: scaffoldMessengerKey,
          navigatorKey: navigatorKey ?? globalNavigatorKey,
          title: AppLocalizations(locale).t(titleKey),
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),
          themeMode: settingsService.themeMode,
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            final isDarkBackground = switch (settingsService.themeMode) {
              ThemeMode.dark => true,
              ThemeMode.light => false,
              ThemeMode.system =>
                WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                    Brightness.dark,
            };
            final backgroundColor = isDarkBackground
                ? AppColors.darkBackground
                : AppColors.lightBackground;
            return Directionality(
              textDirection: textDirection,
              child: ColoredBox(
                color: backgroundColor,
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          home: _PushLifecycleScope(child: home),
        );
      },
    );
  }
}

class _PushLifecycleScope extends StatefulWidget {
  final Widget child;

  const _PushLifecycleScope({required this.child});

  @override
  State<_PushLifecycleScope> createState() => _PushLifecycleScopeState();
}

class _PushLifecycleScopeState extends State<_PushLifecycleScope> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (GetIt.instance.isRegistered<PushNotificationService>()) {
        GetIt.instance<PushNotificationService>().start();
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
