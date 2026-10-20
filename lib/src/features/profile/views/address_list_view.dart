import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/back_button_wrapper.dart';
import 'package:go_router/go_router.dart';
import '../../../core/localization/app_language.dart';
import '../controllers/address_controller.dart';
import '../models/address_model.dart';
import 'package:delitopia_v2/src/core/utils/helpers.dart';
import '../../../core/widgets/app_dialog.dart';

class AddressListView extends ConsumerWidget {
  /// Jika [selectionMode] = true, tap pada alamat akan mengembalikan
  /// objek [Address] ke caller melalui Navigator.pop(context, address).
  final bool selectionMode;

  const AddressListView({super.key, this.selectionMode = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addressesAsync = ref.watch(addressesProvider);
    final lang = ref.watch(appLanguageProvider);

    return BackButtonWrapper(
      child: Scaffold(
        appBar: AppBar(
          leading: selectionMode
              ? IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                )
              : const AppBackButton(
                  backRoute: '/navigation?index=4',
                  color: Colors.white,
                ),
          title: Text(
            selectionMode
                ? (lang == AppLanguage.indonesia
                    ? 'Pilih Alamat Pengiriman'
                    : 'Select Delivery Address')
                : tr.get('my_addresses', lang),
          ),
          backgroundColor: const Color(0xFFDD2222),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: lang == AppLanguage.indonesia
                  ? 'Tambah Alamat'
                  : 'Add Address',
              onPressed: () => context.push('/profile/addresses/add'),
            ),
          ],
        ),
        body: addressesAsync.when(
          data: (addresses) {
            if (addresses.isEmpty) {
              return Center(
                  child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_off, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(tr.get('no_addresses_saved', lang)),
                  if (selectionMode) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        lang == AppLanguage.indonesia
                            ? 'Tambah alamat baru untuk melanjutkan pengiriman'
                            : 'Add a new address to proceed with delivery',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/profile/addresses/add'),
                    icon: const Icon(Icons.add),
                    label: Text(tr.get('add_address', lang)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDD2222),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ));
            }

            return RefreshIndicator(
              onRefresh: () => ref.refresh(addressesProvider.future),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: addresses.length,
                itemBuilder: (context, index) {
                  final address = addresses[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: address.isDefault
                            ? const Color(0xFFDD2222).withValues(alpha: 0.3)
                            : Colors.grey.shade200,
                        width: address.isDefault ? 1.2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: selectionMode
                            ? () => Navigator.pop(context, address)
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 4, 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Content Column
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Title row: Label & Utama badge
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            address.label,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Color(0xFF202124),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (address.isDefault) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF4CAF50),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              lang == AppLanguage.indonesia
                                                  ? 'Utama'
                                                  : 'Default',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.normal,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    // Full Address
                                    Text(
                                      address.fullAddress,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 13,
                                        height: 1.35,
                                      ),
                                    ),
                                    if (address.recipientName != null &&
                                        address.recipientName!.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.person_rounded,
                                            size: 15,
                                            color: Colors.blue.shade700,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            address.recipientName!,
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              // 3-dots popup button at the far right
                              PopupMenuButton<String>(
                                color: Colors.white,
                                surfaceTintColor: Colors.transparent,
                                elevation: 6,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                icon: const Icon(
                                  Icons.more_vert,
                                  color: Colors.black54,
                                  size: 22,
                                ),
                                onSelected: (value) async {
                                  if (value == 'edit') {
                                    context.push(
                                        '/profile/addresses/edit/${address.id}');
                                  } else if (value == 'delete') {
                                    _showDeleteDialog(context, ref,
                                        address.id.toString(), address.label);
                                  } else if (value == 'default') {
                                    try {
                                      await ref
                                          .read(addressControllerProvider.notifier)
                                          .setDefaultAddress(address.id);
                                      if (context.mounted) {
                                        Helpers.showSnackbar(context,
                                            tr.get('default_address_updated', lang));
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        Helpers.showSnackbar(
                                          context,
                                          '${tr.get('something_went_wrong', lang)}: ${e.toString()}',
                                        );
                                      }
                                    }
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.edit_outlined,
                                            size: 18, color: Colors.black87),
                                        const SizedBox(width: 10),
                                        Text(tr.get('edit', lang)),
                                      ],
                                    ),
                                  ),
                                  if (!address.isDefault)
                                    PopupMenuItem(
                                      value: 'default',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.star_outline,
                                              size: 18, color: Colors.green),
                                          const SizedBox(width: 10),
                                          Text(tr.get('set_as_default', lang)),
                                        ],
                                      ),
                                    ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.delete_outline,
                                            size: 18, color: Colors.red),
                                        const SizedBox(width: 10),
                                        Text(
                                          tr.get('delete', lang),
                                          style: const TextStyle(color: Colors.red),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 60, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                    '${tr.get('something_went_wrong', lang)}: ${error.toString()}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.refresh(addressesProvider),
                  child: Text(
                      lang == AppLanguage.indonesia ? 'Coba Lagi' : 'Retry'),
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => context.push('/profile/addresses/add'),
          backgroundColor: const Color(0xFFDD2222),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    String addressId,
    String? label,
  ) async {
    final lang = ref.read(appLanguageProvider);
    final confirmed = await AppDialog.showConfirm(
      context: context,
      title: tr.get('delete_address_title', lang),
      message: lang == AppLanguage.indonesia
          ? 'Yakin ingin menghapus ${label ?? 'alamat ini'}?'
          : 'Are you sure you want to delete ${label ?? 'this address'}?',
      confirmText: tr.get('delete', lang),
      cancelText: tr.get('cancel', lang),
      type: AppDialogType.danger,
    );

    if (!confirmed) return;

    try {
      await ref
          .read(addressControllerProvider.notifier)
          .deleteAddress(int.parse(addressId));
      if (context.mounted) {
        Helpers.showSnackbar(
            context,
            lang == AppLanguage.indonesia
                ? 'Alamat berhasil dihapus'
                : 'Address deleted',
            backgroundColor: Colors.green);
      }
    } catch (e) {
      if (context.mounted) {
        Helpers.showSnackbar(
            context,
            '${tr.get('something_went_wrong', lang)}: ${e.toString()}',
            backgroundColor: Colors.red);
      }
    }
  }
}
