import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get_it/get_it.dart';

import '../../design_system/theme/app_theme.dart';
import '../localization/app_locale_controller.dart';
import '../localization/app_localizations.dart';
import '../notifications/push_notification_service.dart';

class AcademyMaterialApp extends StatelessWidget {
  final String titleKey;
  final Widget home;
  final ThemeMode themeMode;

  const AcademyMaterialApp({
    super.key,
    required this.titleKey,
    required this.home,
    this.themeMode = ThemeMode.system,
  });

  @override
  Widget build(BuildContext context) {
    final localeController = GetIt.instance<AppLocaleController>();

    return ListenableBuilder(
      listenable: localeController,
      builder: (context, _) {
        final locale = localeController.locale;
        final textDirection = locale.languageCode == 'ar'
            ? TextDirection.rtl
            : TextDirection.ltr;

        return MaterialApp(
          title: AppLocalizations(locale).t(titleKey),
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),
          themeMode: themeMode,
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            return Directionality(
              textDirection: textDirection,
              child: child ?? const SizedBox.shrink(),
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
