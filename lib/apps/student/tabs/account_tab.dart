import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/network/supabase_client_wrapper.dart';
import '../../../core/settings/app_settings_screen.dart';
import '../../../design_system/components/glass_card.dart';
import '../../../design_system/tokens/colors.dart';
import '../../../design_system/tokens/typography.dart';
import '../../../design_system/widgets/portal_components.dart';
import '../../../features/auth/data/repositories/supabase_auth_repository.dart';
import '../../../features/auth/domain/models/user_profile.dart';
import '../../../features/communication/domain/models/announcement.dart';
import '../../../features/communication/domain/models/notification.dart';
import '../../../features/payments/domain/models/payment_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String _formatDate(DateTime? dt) => dt == null ? '' : DateFormat.yMMMd().format(dt);
String _formatMoney(int minor, String currency) {
  final value = minor / 100;
  final clean = value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
  return '$clean $currency';
}

class AccountTab extends StatelessWidget {
  final UserProfile? profile;
  final String role;
  final String? studentId;
  final FinancialSummary? financialSummary;
  final List<Invoice> invoices;
  final List<Receipt> receipts;
  final List<Announcement> announcements;
  final List<AppNotification> notifications;
  final int unreadCount;
  final bool isLoading;
  final VoidCallback onSignOut;
  final Future<void> Function() onProfileChanged;
  final ValueChanged<AppNotification> onMarkRead;
  final VoidCallback onMarkAllRead;
  final ValueChanged<Announcement> onAcknowledge;

  const AccountTab({
    super.key,
    required this.profile,
    required this.role,
    required this.studentId,
    required this.financialSummary,
    required this.invoices,
    required this.receipts,
    required this.announcements,
    required this.notifications,
    required this.unreadCount,
    required this.isLoading,
    required this.onSignOut,
    required this.onProfileChanged,
    required this.onMarkRead,
    required this.onMarkAllRead,
    required this.onAcknowledge,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverAppBar(
          backgroundColor: bgColor,
          surfaceTintColor: Colors.transparent,
          pinned: true,
          title: Text(context.tr('Account'), style: AppTypography.displaySmall(textPrimary).copyWith(fontWeight: FontWeight.w800, fontSize: 24)),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // ── Avatar card ──
              FadeInSlide(
                duration: const Duration(milliseconds: 500),
                child: _ProfileHeroCard(profile: profile, role: role, studentId: studentId),
              ),
              const SizedBox(height: 32),

              // ── Notifications ──
              FadeInSlide(
                duration: const Duration(milliseconds: 500),
                delay: const Duration(milliseconds: 100),
                child: _AccountSectionHeader(
                  text: context.tr('Notifications'),
                  badge: unreadCount > 0 ? '$unreadCount' : null,
                  action: unreadCount > 0 ? context.tr('Mark all read') : null,
                  onAction: onMarkAllRead,
                ),
              ),
              const SizedBox(height: 12),
              FadeInSlide(
                duration: const Duration(milliseconds: 600),
                delay: const Duration(milliseconds: 150),
                child: _NotificationsGroup(notifications: notifications, onMarkRead: onMarkRead),
              ),
              const SizedBox(height: 32),

              // ── Announcements ──
              FadeInSlide(
                duration: const Duration(milliseconds: 500),
                delay: const Duration(milliseconds: 200),
                child: _AccountSectionHeader(text: context.tr('Announcements')),
              ),
              const SizedBox(height: 12),
              FadeInSlide(
                duration: const Duration(milliseconds: 600),
                delay: const Duration(milliseconds: 250),
                child: _AnnouncementsGroup(announcements: announcements, onAcknowledge: onAcknowledge),
              ),
              const SizedBox(height: 32),

              // ── Billing ──
              FadeInSlide(
                duration: const Duration(milliseconds: 500),
                delay: const Duration(milliseconds: 300),
                child: _AccountSectionHeader(text: context.tr('Billing')),
              ),
              const SizedBox(height: 12),
              FadeInSlide(
                duration: const Duration(milliseconds: 600),
                delay: const Duration(milliseconds: 350),
                child: _BillingGroup(summary: financialSummary, invoices: invoices, receipts: receipts),
              ),
              const SizedBox(height: 32),

              // ── Profile edit ──
              FadeInSlide(
                duration: const Duration(milliseconds: 500),
                delay: const Duration(milliseconds: 400),
                child: _AccountSectionHeader(text: context.tr('Profile')),
              ),
              const SizedBox(height: 12),
              FadeInSlide(
                duration: const Duration(milliseconds: 600),
                delay: const Duration(milliseconds: 450),
                child: _ProfileEditCard(profile: profile, onProfileChanged: onProfileChanged),
              ),
              const SizedBox(height: 32),

              // ── App settings ──
              FadeInSlide(
                duration: const Duration(milliseconds: 500),
                delay: const Duration(milliseconds: 500),
                child: _AccountSectionHeader(text: context.tr('Settings')),
              ),
              const SizedBox(height: 12),
              FadeInSlide(
                duration: const Duration(milliseconds: 600),
                delay: const Duration(milliseconds: 550),
                child: _AppleGroupedList(
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AppSettingsScreen())),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                                child: const Icon(Icons.tune_rounded, color: AppColors.info, size: 20),
                              ),
                              const SizedBox(width: 16),
                              Expanded(child: Text(context.tr('App Settings'), style: AppTypography.bodyMedium(textPrimary).copyWith(fontWeight: FontWeight.w600))),
                              Icon(Icons.chevron_right_rounded, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ── Sign out ──
              FadeInSlide(
                duration: const Duration(milliseconds: 600),
                delay: const Duration(milliseconds: 600),
                child: _AppleGroupedList(
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onSignOut,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                                child: const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                              ),
                              const SizedBox(width: 16),
                              Text(context.tr('Sign Out'), style: AppTypography.bodyMedium(AppColors.error).copyWith(fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _ProfileHeroCard extends StatelessWidget {
  final UserProfile? profile;
  final String role;
  final String? studentId;

  const _ProfileHeroCard({required this.profile, required this.role, required this.studentId});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final name = profile?.fullName ?? 'Student';
    final email = profile?.email ?? '';
    final avatarUrl = profile?.avatarUrl;

    return GlassCard(
      padding: const EdgeInsets.all(24),
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      child: Row(
        children: [
          // Avatar
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 2),
            ),
            child: CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null || avatarUrl.isEmpty
                  ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'S', style: AppTypography.displaySmall(AppColors.primary).copyWith(fontWeight: FontWeight.w800))
                  : null,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTypography.titleLarge(textPrimary).copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(email, style: AppTypography.caption(textSecondary).copyWith(fontWeight: FontWeight.w500)),
                ],
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Text(role, style: AppTypography.caption(AppColors.primary).copyWith(fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationsGroup extends StatelessWidget {
  final List<AppNotification> notifications;
  final ValueChanged<AppNotification> onMarkRead;

  const _NotificationsGroup({required this.notifications, required this.onMarkRead});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    if (notifications.isEmpty) return _InlinePlaceholder(text: context.tr('No notifications yet.'));

    final recent = notifications.take(5).toList();
    return _AppleGroupedList(
      children: recent.map((n) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onMarkRead(n),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: (n.isRead ? AppColors.info : AppColors.warning).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(n.isRead ? Icons.notifications_none_rounded : Icons.notifications_rounded, color: n.isRead ? AppColors.info : AppColors.warning, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n.title, style: AppTypography.bodyMedium(textPrimary).copyWith(fontWeight: n.isRead ? FontWeight.w600 : FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text('${n.message}  ·  ${_formatDate(n.createdAt)}', style: AppTypography.caption(textSecondary).copyWith(fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                if (!n.isRead) ...[
                  const SizedBox(width: 12),
                  Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.warning, shape: BoxShape.circle)),
                ],
              ],
            ),
          ),
        ),
      )).toList(),
    );
  }
}

class _AnnouncementsGroup extends StatelessWidget {
  final List<Announcement> announcements;
  final ValueChanged<Announcement> onAcknowledge;

  const _AnnouncementsGroup({required this.announcements, required this.onAcknowledge});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    if (announcements.isEmpty) return _InlinePlaceholder(text: context.tr('No announcements yet.'));

    return Column(
      children: announcements.map((a) {
        final urgent = a.priority == AnnouncementPriority.urgent;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderColor: urgent ? AppColors.error.withValues(alpha: 0.4) : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(urgent ? Icons.warning_amber_rounded : Icons.campaign_rounded, color: urgent ? AppColors.error : AppColors.info, size: 20),
                    const SizedBox(width: 12),
                    Expanded(child: Text(a.title, style: AppTypography.titleMedium(textPrimary).copyWith(fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    PortalStatusChip(status: a.priority.name),
                  ],
                ),
                const SizedBox(height: 12),
                Text(a.body, style: AppTypography.bodyMedium(textSecondary).copyWith(height: 1.4)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: Text(_formatDate(a.publishAt), style: AppTypography.caption(textSecondary).copyWith(fontWeight: FontWeight.w600))),
                    if (a.requiresAcknowledgement)
                      a.isAcknowledged
                          ? PortalStatusChip(status: context.tr('Acknowledged'))
                          : FilledButton.icon(
                              style: FilledButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                              onPressed: () => onAcknowledge(a),
                              icon: const Icon(Icons.check_rounded, size: 16),
                              label: Text(context.tr('Acknowledge'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                            ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _BillingGroup extends StatelessWidget {
  final FinancialSummary? summary;
  final List<Invoice> invoices;
  final List<Receipt> receipts;

  const _BillingGroup({required this.summary, required this.invoices, required this.receipts});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    if (summary == null && invoices.isEmpty && receipts.isEmpty) {
      return _InlinePlaceholder(text: context.tr('No billing records.'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (summary != null) ...[
          PortalMetricGrid(
            children: [
              PortalMetricCard(label: context.tr('Total Invoiced'), value: _formatMoney(summary!.totalDueMinor, summary!.currency), icon: Icons.payments_rounded, accentColor: AppColors.warning),
              PortalMetricCard(label: context.tr('Paid'), value: _formatMoney(summary!.totalPaidMinor, summary!.currency), icon: Icons.check_circle_rounded, accentColor: AppColors.success),
              PortalMetricCard(label: context.tr('Balance'), value: _formatMoney(summary!.remainingBalanceMinor, summary!.currency), icon: Icons.wallet_rounded, accentColor: AppColors.error),
              PortalMetricCard(label: context.tr('Invoices'), value: '${summary!.invoiceCount}', icon: Icons.receipt_long_rounded, accentColor: AppColors.info),
            ],
          ),
          const SizedBox(height: 20),
        ],

        if (invoices.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(context.tr('Invoices'), style: AppTypography.caption(textSecondary).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          ),
          _AppleGroupedList(
            children: invoices.map((inv) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: (inv.status == 'paid' ? AppColors.success : AppColors.warning).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.receipt_long_rounded, color: inv.status == 'paid' ? AppColors.success : AppColors.warning, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(inv.invoiceNumber, style: AppTypography.bodyMedium(textPrimary).copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('${_formatMoney(inv.totalMinor, inv.currency)}  ·  Due ${_formatDate(inv.dueAt)}', style: AppTypography.caption(textSecondary).copyWith(fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  PortalStatusChip(status: inv.status),
                ],
              ),
            )).toList(),
          ),
          const SizedBox(height: 20),
        ],

        if (receipts.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(context.tr('Receipts'), style: AppTypography.caption(textSecondary).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          ),
          _AppleGroupedList(
            children: receipts.map((r) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.receipt_rounded, color: AppColors.success, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.receiptNumber.isEmpty ? 'Receipt ${r.id.substring(0, 8)}' : r.receiptNumber, style: AppTypography.bodyMedium(textPrimary).copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('${_formatMoney(r.amountMinor, r.currency)}  ·  ${_formatDate(r.issuedAt)}', style: AppTypography.caption(textSecondary).copyWith(fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),
            )).toList(),
          ),
        ],
      ],
    );
  }
}

class _ProfileEditCard extends StatefulWidget {
  final UserProfile? profile;
  final Future<void> Function() onProfileChanged;

  const _ProfileEditCard({required this.profile, required this.onProfileChanged});

  @override
  State<_ProfileEditCard> createState() => _ProfileEditCardState();
}

class _ProfileEditCardState extends State<_ProfileEditCard> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _avatarCtrl;
  final TextEditingController _passwordCtrl = TextEditingController();
  bool _savingProfile = false;
  bool _changingPw = false;
  String? _msg;
  String? _err;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _nameCtrl = TextEditingController(text: p?.fullName ?? '');
    _phoneCtrl = TextEditingController(text: p?.phoneNumber ?? '');
    _avatarCtrl = TextEditingController(text: p?.avatarUrl ?? '');
  }

  @override
  void didUpdateWidget(covariant _ProfileEditCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile?.id != widget.profile?.id || oldWidget.profile?.updatedAt != widget.profile?.updatedAt) {
      _nameCtrl.text = widget.profile?.fullName ?? '';
      _phoneCtrl.text = widget.profile?.phoneNumber ?? '';
      _avatarCtrl.text = widget.profile?.avatarUrl ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _phoneCtrl.dispose(); _avatarCtrl.dispose(); _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final p = widget.profile;
    if (p == null || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _savingProfile = true; _msg = null; _err = null; });
    try {
      final repo = SupabaseAuthRepository(SupabaseClientWrapper(Supabase.instance.client));
      await repo.updateProfile(p.copyWith(
        fullName: _nameCtrl.text.trim(),
        phoneNumber: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        avatarUrl: _avatarCtrl.text.trim().isEmpty ? null : _avatarCtrl.text.trim(),
      ));
      await widget.onProfileChanged();
      if (!mounted) return;
      setState(() { _savingProfile = false; _msg = 'Profile updated successfully.'; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _savingProfile = false; _err = e.toString(); });
    }
  }

  Future<void> _changePassword() async {
    final pw = _passwordCtrl.text.trim();
    if (pw.length < 6) { setState(() { _err = 'Password must be at least 6 characters.'; }); return; }
    setState(() { _changingPw = true; _msg = null; _err = null; });
    try {
      final repo = SupabaseAuthRepository(SupabaseClientWrapper(Supabase.instance.client));
      await repo.updatePassword(pw);
      _passwordCtrl.clear();
      if (!mounted) return;
      setState(() { _changingPw = false; _msg = 'Password updated successfully.'; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _changingPw = false; _err = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GlassCard(
      padding: EdgeInsets.zero,
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      child: Column(
        children: [
          if (_msg != null)
            _NoticeBanner(icon: Icons.check_circle_rounded, color: AppColors.success, text: _msg!),
          if (_err != null)
            _NoticeBanner(icon: Icons.error_outline_rounded, color: AppColors.error, text: _err!),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(labelText: context.tr('Full name'), prefixIcon: const Icon(Icons.person_outline)),
                    validator: (v) => v == null || v.trim().isEmpty ? context.tr('Name is required') : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneCtrl,
                    decoration: InputDecoration(labelText: context.tr('Phone number'), prefixIcon: const Icon(Icons.phone_outlined)),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _avatarCtrl,
                    decoration: InputDecoration(labelText: context.tr('Avatar URL'), prefixIcon: const Icon(Icons.image_outlined)),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: _savingProfile ? null : _saveProfile,
                      icon: _savingProfile ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Icon(Icons.save_rounded, size: 20),
                      label: Text(context.tr('Save Profile'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _passwordCtrl,
                    decoration: InputDecoration(labelText: context.tr('New password'), prefixIcon: const Icon(Icons.key_outlined)),
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: _changingPw ? null : _changePassword,
                      icon: _changingPw ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5)) : const Icon(Icons.key_rounded, size: 20),
                      label: Text(context.tr('Update Password'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppleGroupedList extends StatelessWidget {
  final List<Widget> children;

  const _AppleGroupedList({required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final dividerColor = isDark ? AppColors.darkBorder.withValues(alpha: 0.6) : AppColors.lightBorder;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 0.6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(height: 0.5, thickness: 0.5, indent: 64, endIndent: 0, color: dividerColor),
          ],
        ],
      ),
    );
  }
}

class _AccountSectionHeader extends StatelessWidget {
  final String text;
  final String? badge;
  final String? action;
  final VoidCallback? onAction;

  const _AccountSectionHeader({required this.text, this.badge, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Text(text.toUpperCase(), style: AppTypography.caption(textSecondary).copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.8, fontSize: 12)),
                if (badge != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.warning, borderRadius: BorderRadius.circular(20)),
                    child: Text(badge!, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                ],
              ],
            ),
          ),
          if (action != null && onAction != null)
            GestureDetector(
              onTap: onAction,
              child: Text(action!, style: AppTypography.caption(AppColors.primary).copyWith(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
        ],
      ),
    );
  }
}

class _InlinePlaceholder extends StatelessWidget {
  final String text;

  const _InlinePlaceholder({required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Container(
      decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderColor, width: 0.6)),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Center(child: Text(text, style: AppTypography.bodyMedium(textSecondary).copyWith(fontWeight: FontWeight.w500))),
    );
  }
}

class _NoticeBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _NoticeBanner({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14))),
        ],
      ),
    );
  }
}
