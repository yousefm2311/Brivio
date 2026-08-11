import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../localization/app_locale_controller.dart';
import '../localization/app_localizations.dart';
import '../notifications/push_notification_service.dart';
import '../services/settings_service.dart';
import '../../design_system/tokens/colors.dart';
import '../../design_system/components/glass_card.dart';
import '../../design_system/widgets/portal_components.dart';

class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PortalPageShell(
      title: context.tr('app_settings'),
      subtitle: 'Manage global configuration, preferences, and security.',
      icon: Icons.settings_suggest,
      accentColor: AppColors.primary,
      child: const AppSettingsPanel(),
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ListenableBuilder(
      listenable: settingsService,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          children: [
            FadeInSlide(
              delay: const Duration(milliseconds: 100),
              child: _SettingsSection(
                title: 'Appearance',
                icon: Icons.palette_outlined,
                accentColor: Colors.purple,
                children: [
                  _SettingsTile(
                    title: 'Theme Mode',
                    subtitle: 'Choose between Light, Dark, or System theme.',
                    icon: Icons.brightness_6_outlined,
                    trailing: SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(value: ThemeMode.system, label: Text('Auto')),
                        ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                        ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                      ],
                      selected: {settingsService.themeMode},
                      onSelectionChanged: (selection) => settingsService.updateThemeMode(selection.first),
                      style: SegmentedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                  _SettingsTile(
                    title: 'Animation Quality',
                    subtitle: 'Use 120fps fluid animations',
                    icon: Icons.animation,
                    trailing: Switch.adaptive(
                      value: true,
                      onChanged: (val) {},
                      activeColor: Colors.purple,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FadeInSlide(
              delay: const Duration(milliseconds: 200),
              child: _SettingsSection(
                title: 'Localization',
                icon: Icons.language,
                accentColor: Colors.blue,
                children: [
                  _SettingsTile(
                    title: context.tr('display_language'),
                    subtitle: context.tr('display_language_subtitle'),
                    icon: Icons.translate,
                    trailing: SegmentedButton<AppLanguage>(
                      segments: [
                        ButtonSegment(value: AppLanguage.english, label: Text(context.tr('english'))),
                        ButtonSegment(value: AppLanguage.arabic, label: Text(context.tr('arabic'))),
                      ],
                      selected: {settingsService.language},
                      onSelectionChanged: (selection) => settingsService.updateLanguage(selection.first),
                      style: SegmentedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                  _SettingsTile(
                    title: 'Time Zone',
                    subtitle: 'Automatic (UTC+03:00)',
                    icon: Icons.access_time,
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FadeInSlide(
              delay: const Duration(milliseconds: 300),
              child: _SettingsSection(
                title: 'Notifications & Alerts',
                icon: Icons.notifications_active_outlined,
                accentColor: Colors.orange,
                children: [
                  _SettingsTile(
                    title: context.tr('push_notifications'),
                    subtitle: context.tr('push_notifications_subtitle'),
                    icon: Icons.phonelink_ring,
                    trailing: Switch.adaptive(
                      value: pushService?.isConfigured ?? true,
                      onChanged: (val) {},
                      activeColor: Colors.orange,
                    ),
                  ),
                  _SettingsTile(
                    title: 'Email Digest',
                    subtitle: 'Receive daily summary of activities',
                    icon: Icons.email_outlined,
                    trailing: Switch.adaptive(
                      value: false,
                      onChanged: (val) {},
                      activeColor: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FadeInSlide(
              delay: const Duration(milliseconds: 400),
              child: _SettingsSection(
                title: 'Security & Privacy',
                icon: Icons.security,
                accentColor: AppColors.success,
                children: [
                  _SettingsTile(
                    title: 'Two-Factor Authentication',
                    subtitle: 'Require 2FA for all admin logins',
                    icon: Icons.vpn_key_outlined,
                    trailing: Switch.adaptive(
                      value: true,
                      onChanged: (val) {},
                      activeColor: AppColors.success,
                    ),
                  ),
                  _SettingsTile(
                    title: 'Data Collection',
                    subtitle: 'Send anonymous usage data to improve the app',
                    icon: Icons.data_usage,
                    trailing: Switch.adaptive(
                      value: false,
                      onChanged: (val) {},
                      activeColor: AppColors.success,
                    ),
                  ),
                  _SettingsTile(
                    title: 'Biometric Login',
                    subtitle: 'Use FaceID/TouchID for quick access',
                    icon: Icons.fingerprint,
                    trailing: Switch.adaptive(
                      value: true,
                      onChanged: (val) {},
                      activeColor: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            Center(
              child: Text(
                'Version 2.0.4 (Build 824)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.5),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: accentColor, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GlassCard(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget trailing;

  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).iconTheme.color?.withOpacity(0.7)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          trailing,
        ],
      ),
    );
  }
}
