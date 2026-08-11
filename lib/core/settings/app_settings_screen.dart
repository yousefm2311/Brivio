import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../localization/app_locale_controller.dart';
import '../localization/app_localizations.dart';
import '../notifications/push_notification_service.dart';
import '../services/settings_service.dart';

class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('app_settings'))),
      body: const AppSettingsPanel(),
    );
  }
}

class AppSettingsPanel extends StatelessWidget {
  const AppSettingsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsService = GetIt.instance<SettingsService>();
    final pushService = GetIt.instance.isRegistered<PushNotificationService>()
        ? GetIt.instance<PushNotificationService>()
        : null;

    return ListenableBuilder(
      listenable: settingsService,
      builder: (context, _) {
        return ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              context.tr('display_language'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SegmentedButton<AppLanguage>(
              segments: [
                ButtonSegment(
                  value: AppLanguage.english,
                  label: Text(context.tr('english')),
                ),
                ButtonSegment(
                  value: AppLanguage.arabic,
                  label: Text(context.tr('arabic')),
                ),
              ],
              selected: {settingsService.language},
              onSelectionChanged: (selection) {
                settingsService.updateLanguage(selection.first);
              },
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('display_language_subtitle'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Divider(height: 32),
            Text(
              'Theme', // Could be context.tr('theme') but hardcoded for now or if l10n is there
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('System'),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Light'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Dark'),
                ),
              ],
              selected: {settingsService.themeMode},
              onSelectionChanged: (selection) {
                settingsService.updateThemeMode(selection.first);
              },
            ),
            const Divider(height: 32),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.notifications_active_outlined),
              title: Text(context.tr('push_notifications')),
              subtitle: Text(context.tr('push_notifications_subtitle')),
              trailing: Chip(
                label: Text(
                  pushService?.isConfigured == true
                      ? context.tr('enabled')
                      : context.tr('disabled'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
