import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import '../../models/company.dart';
import '../../services/company_service.dart';
import 'company_form.dart';
import 'perimeters_screen.dart';

class CompaniesTab extends StatefulWidget {
  const CompaniesTab({super.key});

  @override
  State<CompaniesTab> createState() => CompaniesTabState();
}

class CompaniesTabState extends State<CompaniesTab> {
  final _service = CompanyService();
  List<Company> _companies = [];
  List<Company> _filtered = [];
  bool _isLoading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> load() => _load();

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await _service.getAll();
      setState(() {
        _companies = data;
        _applySearch();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar: $e'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applySearch() {
    final q = _search.toLowerCase();
    _filtered = _companies.where((c) {
      return c.name.toLowerCase().contains(q) ||
          (c.cnpj?.contains(q) ?? false) ||
          (c.email?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  Future<void> _openForm([Company? company]) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CompanyForm(company: company)),
    );
    if (result == true) _load();
  }

  Future<void> _toggleActive(Company company) async {
    try {
      await _service.toggleActive(company.id, !company.active);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _confirmDelete(Company company) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir empresa'),
        content: Text(
            'Tem certeza que deseja excluir "${company.name}"? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _service.delete(company.id);
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao excluir: $e'),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: (v) => setState(() {
              _search = v;
              _applySearch();
            }),
            decoration: InputDecoration(
              hintText: 'Buscar empresa...',
              prefixIcon: Icon(Icons.search, color: AppTheme.of(context).textSecondary),
              filled: true,
              fillColor: AppTheme.of(context).surface,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.of(context).divider)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.of(context).divider)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.accent, width: 2)),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : _filtered.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.primary,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) => _buildCard(_filtered[i]),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.business_outlined, size: 56, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            _search.isEmpty ? 'Nenhuma empresa cadastrada' : 'Nenhum resultado',
            style: TextStyle(color: AppTheme.of(context).textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Company company) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.of(context).divider),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor:
              company.active ? AppColors.primary : Colors.grey[300],
          child: Text(
            company.name[0].toUpperCase(),
            style: TextStyle(
              color: company.active ? Colors.white : Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          company.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (company.cnpj != null) Text('CNPJ: ${company.cnpj}'),
            if (company.email != null)
              Text(company.email!,
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.of(context).textSecondary)),
            const SizedBox(height: 6),
            Row(
              children: [
                _badge(
                  company.active ? 'Ativa' : 'Inativa',
                  company.active ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 6),
                if (company.requiresPerimeter)
                  _badge('Perímetro obrigatório', AppColors.accent),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: AppTheme.of(context).textSecondary),
          onSelected: (value) {
            if (value == 'edit') _openForm(company);
            if (value == 'perimeters') {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => PerimetersScreen(company: company),
              ));
            }
            if (value == 'toggle') _toggleActive(company);
            if (value == 'delete') _confirmDelete(company);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Editar')),
            const PopupMenuItem(
              value: 'perimeters',
              child: Row(children: [
                Icon(Icons.account_tree_outlined, size: 18),
                SizedBox(width: 8),
                Text('Perímetros'),
              ]),
            ),
            PopupMenuItem(
              value: 'toggle',
              child: Text(company.active ? 'Desativar' : 'Ativar'),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Excluir', style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color is MaterialColor ? color[700] : color,
        ),
      ),
    );
  }
}
