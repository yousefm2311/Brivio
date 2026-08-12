import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../design_system/tokens/colors.dart';
import '../../../design_system/tokens/typography.dart';
import '../../../design_system/components/glass_card.dart';
import 'workspace_view_model.dart';
import 'package:provider/provider.dart';

class WorkspaceTab extends StatelessWidget {
  final String teacherId;

  const WorkspaceTab({super.key, required this.teacherId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => WorkspaceViewModel(),
      child: const _WorkspaceTabContent(),
    );
  }
}

class _WorkspaceTabContent extends StatelessWidget {
  const _WorkspaceTabContent();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final viewModel = context.watch<WorkspaceViewModel>();

    return Container(
      color: bgColor,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.tr('Workspace'),
                style: AppTypography.displaySmall(textPrimary).copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              GlassCard(
                borderRadius: BorderRadius.circular(12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.add, color: textPrimary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      context.tr('Upload'),
                      style: AppTypography.bodyMedium(textPrimary).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              itemCount: viewModel.materials.length,
              itemBuilder: (context, index) {
                final material = viewModel.materials[index];
                return _buildMaterialCard(context, material, textPrimary);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialCard(BuildContext context, StudyMaterial material, Color textPrimary) {
    IconData icon;
    Color iconColor;

    switch (material.type) {
      case StudyMaterialType.pdf:
        icon = Icons.picture_as_pdf;
        iconColor = Colors.redAccent;
        break;
      case StudyMaterialType.video:
        icon = Icons.play_circle_fill;
        iconColor = Colors.blueAccent;
        break;
      case StudyMaterialType.summary:
        icon = Icons.article;
        iconColor = Colors.orangeAccent;
        break;
    }

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 32),
          ),
          const Spacer(),
          Text(
            material.title,
            style: AppTypography.bodyLarge(textPrimary).copyWith(fontWeight: FontWeight.w700),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                material.size,
                style: AppTypography.bodySmall(textPrimary.withValues(alpha: 0.6)),
              ),
              Icon(Icons.more_vert, color: textPrimary.withValues(alpha: 0.6), size: 16),
            ],
          ),
        ],
      ),
    );
  }
}
