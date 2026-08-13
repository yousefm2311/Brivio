import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/settings/app_settings_screen.dart';
import '../../../design_system/tokens/colors.dart';
import '../../../design_system/tokens/typography.dart';
import '../../../design_system/components/glass_card.dart';
import '../../../core/di/injection.dart';
import '../../../features/auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../../features/communication/domain/repositories/i_notification_repository.dart';
import '../../../features/communication/presentation/screens/notification_center_screen.dart';
import '../../../features/communication/presentation/viewmodels/notification_center_viewmodel.dart';
import '../../../features/payments/presentation/screens/teacher_finance_screen.dart';
import '../../../features/people/presentation/screens/teacher_profile_screen.dart';
import '../screens/teacher_helpdesk_screen.dart';

class AccountTab extends StatefulWidget {
  final String teacherId;
  final AuthViewModel authViewModel;

  const AccountTab({
    super.key,
    required this.teacherId,
    required this.authViewModel,
  });

  @override
  State<AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<AccountTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  late final NotificationCenterViewModel _notificationViewModel;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this);
    _notificationViewModel = NotificationCenterViewModel(
      getIt<INotificationRepository>(),
    );
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _notificationViewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final bgColor = isDark
        ? AppColors.darkBackground
        : AppColors.lightBackground;
    final surfaceColor = isDark ? AppColors.darkCard : AppColors.lightCard;

    return Column(
      children: [
        Container(
          color: bgColor,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeInSlide(
                duration: const Duration(milliseconds: 400),
                child: Text(
                  context.tr('Account'),
                  style: AppTypography.displaySmall(textPrimary).copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FadeInSlide(
                duration: const Duration(milliseconds: 500),
                delay: const Duration(milliseconds: 100),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabCtrl,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: textPrimary,
                    unselectedLabelColor: textPrimary.withValues(alpha: 0.5),
                    labelStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                    tabs: [
                      Tab(text: context.tr('Profile')),
                      Tab(text: context.tr('Finance')),
                      Tab(text: context.tr('Helpdesk')),
                      Tab(text: context.tr('Notifications')),
                      Tab(text: context.tr('Settings')),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              TeacherProfileScreen(authViewModel: widget.authViewModel),
              TeacherFinanceScreen(teacherId: widget.teacherId),
              const TeacherHelpdeskScreen(),
              NotificationCenterScreen(viewModel: _notificationViewModel),
              const AppSettingsScreen(),
            ],
          ),
        ),
      ],
    );
  }
}
