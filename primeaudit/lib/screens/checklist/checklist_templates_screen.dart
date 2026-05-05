import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import 'checklist_template_list_screen.dart';

/// Tela de seleção de categoria de checklist.
///
/// Exibe 3 cards centralizados (Industrial, Transportadora, Meus checklists).
/// Ao tocar num card navega para [ChecklistTemplateListScreen] com a categoria filtrada.
class ChecklistTemplatesScreen extends StatelessWidget {
  const ChecklistTemplatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.of(context).background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'Checklist',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CategoryCard(
                icon: Icons.factory_outlined,
                color: Colors.orange,
                title: 'Industrial',
                description: 'Templates de inspeção industrial',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ChecklistTemplateListScreen(
                      category: 'industrial',
                      title: 'Industrial',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _CategoryCard(
                icon: Icons.local_shipping_outlined,
                color: const Color(0xFF1565C0),
                title: 'Transportadora',
                description: 'Templates para transportadoras',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ChecklistTemplateListScreen(
                      category: 'transportadora',
                      title: 'Transportadora',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _CategoryCard(
                icon: Icons.checklist_rounded,
                color: AppColors.accent,
                title: 'Meus checklists',
                description: 'Templates personalizados criados por você',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ChecklistTemplateListScreen(
                      category: 'meus',
                      title: 'Meus checklists',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: t.divider),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
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
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: t.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
