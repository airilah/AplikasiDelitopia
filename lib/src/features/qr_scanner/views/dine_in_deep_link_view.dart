import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/utils/helpers.dart';
import '../../../shared/models/brand_model.dart';
import '../../../shared/models/table_session_model.dart';
import '../../../shared/services/service_providers.dart' show branchesProvider;
import '../../menu/views/brand_branch_selection_view.dart';

class DineInDeepLinkView extends ConsumerStatefulWidget {
  final String? branchId;
  final String? brandId;
  final String? table;
  final String? zone;

  const DineInDeepLinkView({
    super.key,
    this.branchId,
    this.brandId,
    this.table,
    this.zone,
  });

  @override
  ConsumerState<DineInDeepLinkView> createState() => _DineInDeepLinkViewState();
}

class _DineInDeepLinkViewState extends ConsumerState<DineInDeepLinkView> {
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _processDeepLink();
    });
  }

  Future<void> _processDeepLink() async {
    final lang = ref.read(appLanguageProvider);
    final rawBranchId = widget.branchId;
    final parsedBranchId = int.tryParse(rawBranchId ?? '');
    final tableNumber = widget.table ?? '';

    if (parsedBranchId == null || tableNumber.isEmpty) {
      if (!mounted) return;
      setState(() {
        _errorMessage = lang == AppLanguage.indonesia
            ? 'Format link meja tidak valid.'
            : 'Invalid table link format.';
      });
      return;
    }

    try {
      int? resolvedBrandId = int.tryParse(widget.brandId ?? '');
      String? resolvedBranchName;
      String? resolvedBrandName;

      // Match branch info from branchesProvider
      try {
        final branches = await ref.read(branchesProvider.future);
        final matched = branches.where((b) => b.id == parsedBranchId);
        if (matched.isNotEmpty) {
          final branch = matched.first;
          resolvedBrandId ??= branch.brandId;
          resolvedBranchName ??= branch.outlet;
          resolvedBrandName ??= branch.brandName;

          // Set active branch & brand in Riverpod
          ref.read(selectedBranchProvider.notifier).state = branch;
          ref.read(selectedBrandProvider.notifier).state = Brand(
            id: branch.brandId,
            name: branch.brandName,
            logo: branch.brandLogo ?? '',
            service: 0,
            tax: 0,
            category: const [],
          );
        }
      } catch (_) {}

      // Save table session
      final finalSession = TableSession(
        branchId: parsedBranchId,
        brandId: resolvedBrandId,
        tableNumber: tableNumber,
        zone: widget.zone,
        branchName: resolvedBranchName,
        brandName: resolvedBrandName,
        isLockedFromQr: true,
      );
      ref.read(tableSessionProvider.notifier).state = finalSession;

      if (!mounted) return;

      final successMsg = lang == AppLanguage.indonesia
          ? 'Meja ${finalSession.tableNumber} terdeteksi! Membuka menu cabang...'
          : 'Table ${finalSession.tableNumber} detected! Opening branch menu...';

      Helpers.showSnackbar(context, successMsg);

      final brandParam = resolvedBrandId ?? 1;
      context.go('${AppRouter.menu}?branchId=${finalSession.branchId}&brandId=$brandParam');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFDD2222),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFDD2222).withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.table_restaurant_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(height: 24),
              if (_errorMessage != null) ...[
                Text(
                  lang == AppLanguage.indonesia ? 'Gagal Membuka Meja' : 'Failed to Open Table',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => context.go(AppRouter.navigation),
                  icon: const Icon(Icons.home_rounded),
                  label: Text(tr.get('go_home', lang)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDD2222),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ] else ...[
                Text(
                  lang == AppLanguage.indonesia
                      ? 'Menghubungkan ke Meja...'
                      : 'Connecting to Table...',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (widget.table != null && widget.table!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDD2222).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFDD2222).withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'Meja ${widget.table}${widget.zone != null && widget.zone!.isNotEmpty ? ' • ${widget.zone}' : ''}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF6B6B),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                const CircularProgressIndicator(
                  color: Color(0xFFDD2222),
                  strokeWidth: 3,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
