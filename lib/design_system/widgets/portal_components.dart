import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../tokens/colors.dart';

class PortalDestination {
  final IconData icon;
  final String label;

  const PortalDestination({required this.icon, required this.label});
}

class PortalScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final int selectedIndex;
  final List<PortalDestination> destinations;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;
  final VoidCallback? onRefresh;
  final VoidCallback? onSignOut;

  const PortalScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.selectedIndex,
    required this.destinations,
    required this.onDestinationSelected,
    required this.body,
    this.onRefresh,
    this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final drawer = _PortalNavigation(
      title: title,
      subtitle: subtitle,
      icon: icon,
      accentColor: accentColor,
      selectedIndex: selectedIndex,
      destinations: destinations,
      onDestinationSelected: (index) {
        onDestinationSelected(index);
        if (!isWide) Navigator.of(context).maybePop();
      },
      onSignOut: onSignOut,
    );

    return Scaffold(
      drawer: isWide ? null : Drawer(child: drawer),
      appBar: isWide
          ? null
          : AppBar(
              title: Text(context.l10n.t(destinations[selectedIndex].label)),
              actions: [
                if (onRefresh != null)
                  IconButton(
                    tooltip: context.tr('refresh'),
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh),
                  ),
              ],
            ),
      body: Row(
        children: [
          if (isWide) SizedBox(width: 288, child: drawer),
          if (isWide) const VerticalDivider(width: 1),
          Expanded(
            child: ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: body,
            ),
          ),
        ],
      ),
    );
  }
}

class _PortalNavigation extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final int selectedIndex;
  final List<PortalDestination> destinations;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback? onSignOut;

  const _PortalNavigation({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.selectedIndex,
    required this.destinations,
    required this.onDestinationSelected,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            right: BorderSide(color: theme.dividerColor.withValues(alpha: .24)),
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: accentColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.t(title),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          context.l10n.t(subtitle),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(10),
                itemCount: destinations.length,
                itemBuilder: (context, index) {
                  final item = destinations[index];
                  final selected = selectedIndex == index;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: ListTile(
                        selected: selected,
                        dense: true,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        selectedTileColor: accentColor.withValues(alpha: .12),
                        leading: Icon(
                          item.icon,
                          color: selected ? accentColor : null,
                        ),
                        title: Text(
                          context.l10n.t(item.label),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: selected
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                        onTap: () => onDestinationSelected(index),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (onSignOut != null)
              Padding(
                padding: const EdgeInsets.all(10),
                child: OutlinedButton.icon(
                  onPressed: onSignOut,
                  icon: const Icon(Icons.logout),
                  label: Text(context.tr('sign_out')),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class PortalHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final Widget? trailing;

  const PortalHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor.withValues(alpha: .22)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: accentColor, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.t(eyebrow).toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: accentColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.t(title),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.t(subtitle),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

class PortalMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onTap;

  const PortalMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: accentColor, size: 22),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right,
                    color: theme.hintColor.withValues(alpha: .6),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.t(label),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PortalMetricGrid extends StatelessWidget {
  final List<Widget> children;

  const PortalMetricGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1180
            ? 4
            : width >= 760
            ? 3
            : width >= 520
            ? 2
            : 1;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: 132,
          children: children,
        );
      },
    );
  }
}

class PortalSectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const PortalSectionTitle({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.t(title),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(context.l10n.t(subtitle!), style: theme.textTheme.bodyMedium),
        ],
      ],
    );
  }
}

class PortalErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const PortalErrorBanner({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
            TextButton(onPressed: onRetry, child: Text(context.tr('retry'))),
          ],
        ),
      ),
    );
  }
}

class PortalAction {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool primary;

  const PortalAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.primary = false,
  });
}

class PortalPageShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final List<PortalAction> actions;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const PortalPageShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.child,
    this.actions = const [],
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    final primaryActions = actions.where((a) => a.primary).toList();
    final secondaryActions = actions.where((a) => !a.primary).toList();

    Widget buildAction(PortalAction action) {
      if (action.primary) {
        return FilledButton.icon(
          onPressed: action.onPressed,
          icon: Icon(action.icon),
          label: Text(context.l10n.t(action.label)),
        );
      }
      return IconButton.filledTonal(
        tooltip: context.l10n.t(action.label),
        onPressed: action.onPressed,
        icon: Icon(action.icon),
      );
    }

    return SafeArea(
      child: Padding(
        padding: padding,
        child: Column(
          children: [
            PortalHeader(
              eyebrow: 'Admin',
              title: title,
              subtitle: subtitle,
              icon: icon,
              accentColor: accentColor,
              trailing: actions.isEmpty
                  ? null
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: [
                        ...secondaryActions.map(buildAction),
                        ...primaryActions.map(buildAction),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class PortalSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final ValueChanged<String>? onChanged;

  const PortalSearchField({
    super.key,
    required this.controller,
    required this.label,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: context.l10n.t(label),
        prefixIcon: const Icon(Icons.search),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: context.l10n.t('Clear search'),
                icon: const Icon(Icons.close),
                onPressed: () {
                  controller.clear();
                  onChanged?.call('');
                },
              ),
      ),
      onChanged: onChanged,
    );
  }
}

class PortalStateView extends StatelessWidget {
  final bool isLoading;
  final String? errorMessage;
  final bool isEmpty;
  final String emptyTitle;
  final String emptySubtitle;
  final IconData emptyIcon;
  final VoidCallback onRetry;
  final Widget child;

  const PortalStateView({
    super.key,
    required this.isLoading,
    required this.errorMessage,
    required this.isEmpty,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.emptyIcon,
    required this.onRetry,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (errorMessage != null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: PortalErrorBanner(message: errorMessage!, onRetry: onRetry),
        ),
      );
    }
    if (isEmpty) {
      final theme = Theme.of(context);
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(emptyIcon, size: 40, color: theme.colorScheme.primary),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.t(emptyTitle),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.l10n.t(emptySubtitle),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return child;
  }
}

class PortalListCard extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final String title;
  final String subtitle;
  final List<Widget> trailing;
  final VoidCallback? onTap;

  const PortalListCard({
    super.key,
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    this.trailing = const [],
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.t(title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      context.l10n.t(subtitle),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (trailing.isNotEmpty) ...[
                const SizedBox(width: 8),
                Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: trailing,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class PortalStatusChip extends StatelessWidget {
  final String status;

  const PortalStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final color = switch (normalized) {
      'active' => AppColors.success,
      'paid' => AppColors.success,
      'published' => AppColors.success,
      'pending' => AppColors.warning,
      'archived' => Colors.blueGrey,
      'suspended' => AppColors.error,
      _ => Theme.of(context).colorScheme.primary,
    };

    return Chip(
      label: Text(context.l10n.t(status).toUpperCase()),
      side: BorderSide(color: color.withValues(alpha: .3)),
      backgroundColor: color.withValues(alpha: .1),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w800),
    );
  }
}
