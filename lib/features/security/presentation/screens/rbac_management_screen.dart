import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/widgets/portal_components.dart';

class RbacManagementScreen extends StatefulWidget {
  const RbacManagementScreen({super.key});

  @override
  State<RbacManagementScreen> createState() => _RbacManagementScreenState();
}

class _RbacManagementScreenState extends State<RbacManagementScreen> {
  List<Map<String, dynamic>> _permissions = [];
  List<Map<String, dynamic>> _roles = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRbacData();
  }

  Future<void> _loadRbacData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final pRes = await Supabase.instance.client
          .from('permissions')
          .select()
          .order('module');
      final rRes = await Supabase.instance.client
          .from('roles')
          .select()
          .order('name');

      if (mounted) {
        setState(() {
          _permissions = (pRes as List<dynamic>)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _roles = (rRes as List<dynamic>)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: PortalPageShell(
        title: 'Security Governance',
        subtitle: 'Inspect enforced permissions and system roles.',
        icon: Icons.security,
        accentColor: AppColors.adminRole,
        actions: [
          PortalAction(
            icon: Icons.refresh,
            label: 'Refresh',
            onPressed: _loadRbacData,
          ),
        ],
        child: Column(
          children: [
            TabBar(
              tabs: [
                Tab(
                  icon: const Icon(Icons.security),
                  text: context.tr('Permissions Catalog'),
                ),
                Tab(
                  icon: const Icon(Icons.admin_panel_settings),
                  text: context.tr('System Roles'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: PortalStateView(
                isLoading: _isLoading,
                errorMessage: _errorMessage,
                isEmpty: false,
                emptyTitle: 'No security data',
                emptySubtitle: 'Run migrations to seed roles and permissions.',
                emptyIcon: Icons.security,
                onRetry: _loadRbacData,
                child: TabBarView(
                  children: [
                    _permissions.isEmpty
                        ? Center(
                            child: Text(
                              context.tr('No system permissions found.'),
                            ),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: _permissions.length,
                            separatorBuilder: (ctx, i) =>
                                const SizedBox(height: 8),
                            itemBuilder: (ctx, i) {
                              final p = _permissions[i];
                              return PortalListCard(
                                icon: Icons.lock_open,
                                accentColor: AppColors.adminRole,
                                title:
                                    p['code'] as String? ?? 'permission.code',
                                subtitle:
                                    '${context.tr('Module')}: ${(p['module'] as String? ?? "core").toUpperCase()} | ${context.tr('Action')}: ${p['action']}',
                                trailing: [
                                  PortalStatusChip(
                                    status: context.tr('enforced'),
                                  ),
                                ],
                              );
                            },
                          ),
                    _roles.isEmpty
                        ? Center(
                            child: Text(context.tr('No system roles found.')),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: _roles.length,
                            separatorBuilder: (ctx, i) =>
                                const SizedBox(height: 8),
                            itemBuilder: (ctx, i) {
                              final r = _roles[i];
                              return PortalListCard(
                                icon: Icons.admin_panel_settings,
                                accentColor: AppColors.success,
                                title: (r['name'] as String? ?? 'role')
                                    .toUpperCase(),
                                subtitle:
                                    (r['description'] as String?) ??
                                    context.tr('System Role'),
                                trailing: const [
                                  Icon(
                                    Icons.verified_user,
                                    color: AppColors.success,
                                  ),
                                ],
                              );
                            },
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
