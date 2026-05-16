import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import 'audit_types_screen.dart';
import '../checklist/checklist_templates_screen.dart';

class ModelsScreen extends StatelessWidget {
  const ModelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.of(context).background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Modelos',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ModelCard(
            icon: Icons.assignment_rounded,
            title: 'Auditorias',
            description: 'Templates e tipos de auditoria',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AuditTypesScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ModelCard(
            icon: Icons.checklist_rounded,
            title: 'Checklists',
            description: 'Templates de checklist',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const ChecklistTemplatesScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ModelCard(
            icon: Icons.feedback_outlined,
            title: 'Feedback',
            description: 'Em breve',
            enabled: false,
          ),
          const SizedBox(height: 12),
          _ModelCard(
            icon: Icons.build_outlined,
            title: 'Controle de equipamentos',
            description: 'Em breve',
            enabled: false,
          ),
          const SizedBox(height: 12),
          _ModelCard(
            icon: Icons.school_outlined,
            title: 'Treinamentos',
            description: 'Em breve',
            enabled: false,
          ),
        ],
      ),
    );
  }
}

class _ModelCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onTap;
  final bool enabled;

  const _ModelCard({
    required this.icon,
    required this.title,
    required this.description,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final color = enabled ? AppColors.primary : t.textSecondary;

    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: t.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: t.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: t.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (enabled)
                Icon(Icons.chevron_right_rounded,
                    color: t.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
