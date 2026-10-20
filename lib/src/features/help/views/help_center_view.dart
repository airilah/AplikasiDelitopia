import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/widgets/back_button_wrapper.dart';
import '../models/help_center_model.dart';
import '../services/help_center_service.dart';

class HelpCenterView extends ConsumerStatefulWidget {
  const HelpCenterView({super.key});

  @override
  ConsumerState<HelpCenterView> createState() => _HelpCenterViewState();
}

class _HelpCenterViewState extends ConsumerState<HelpCenterView> {
  final HelpCenterService _service = HelpCenterService();
  final TextEditingController _searchController = TextEditingController();

  HelpSupportSettings _settings = HelpSupportSettings.defaultSettings;
  List<HelpFaqCategory> _categories = [];
  List<HelpFaqItem> _allFaqs = [];

  bool _isLoading = true;
  int? _selectedCategoryId; // null = Semua
  int? _expandedFaqId;
  final Set<int> _ratedFaqIds = {}; // FAQ IDs where user already voted
  final Set<int> _unhelpfulFaqIds = {}; // FAQ IDs where user voted "Tidak"

  bool _isId(AppLanguage lang) => lang == AppLanguage.indonesia;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final overview = await _service.fetchHelpOverview();
      final loadedSettings = overview['settings'] as HelpSupportSettings?;
      final loadedCats = overview['categories'] as List<HelpFaqCategory>? ?? [];
      final loadedFaqs = await _service.fetchFaqs();

      if (mounted) {
        setState(() {
          if (loadedSettings != null) _settings = loadedSettings;
          _categories = loadedCats;
          _allFaqs = loadedFaqs.isNotEmpty ? loadedFaqs : _fallbackFaqs();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _allFaqs = _fallbackFaqs();
          _isLoading = false;
        });
      }
    }
  }

  List<HelpFaqItem> _filteredFaqs(bool isId) {
    final query = _searchController.text.trim().toLowerCase();

    return _allFaqs.where((faq) {
      // Category filter
      if (_selectedCategoryId != null && faq.categoryId != _selectedCategoryId) {
        return false;
      }

      // Search filter
      if (query.isNotEmpty) {
        final q = isId ? faq.questionId.toLowerCase() : faq.questionEn.toLowerCase();
        final a = isId ? faq.answerId.toLowerCase() : faq.answerEn.toLowerCase();
        if (!q.contains(query) && !a.contains(query)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Future<void> _handleFeedback(int faqId, bool isHelpful, bool isId) async {
    if (_ratedFaqIds.contains(faqId)) return;

    setState(() {
      _ratedFaqIds.add(faqId);
      if (!isHelpful) {
        _unhelpfulFaqIds.add(faqId);
      }
    });

    await _service.sendFeedback(faqId, isHelpful);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isHelpful
                ? (isId ? 'Terima kasih atas tanggapan Anda! 👍' : 'Thank you for your feedback! 👍')
                : (isId
                    ? 'Mohon maaf atas ketidaknyamanan. Anda dapat menghubungi CS kami di bawah.'
                    : 'Sorry for the inconvenience. You can contact support below.'),
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: isHelpful ? Colors.green[700] : Colors.grey[800],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);
    final isId = _isId(lang);
    final faqs = _filteredFaqs(isId);

    return BackButtonWrapper(
      backRoute: '/navigation?index=4',
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          leading: const AppBackButton(
            backRoute: '/navigation?index=4',
            color: Colors.white,
          ),
          title: Text(
            isId ? 'PUSAT BANTUAN' : 'HELP CENTER',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          backgroundColor: const Color(0xFFDD2222),
          foregroundColor: Colors.white,
        ),
        body: RefreshIndicator(
          color: const Color(0xFFDD2222),
          backgroundColor: Colors.white,
          onRefresh: _loadData,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            padding: const EdgeInsets.all(16),
            children: [
            // 1. Search Bar (Hero element)
            _buildSearchBar(isId),

            const SizedBox(height: 16),

            // 2. Category Filter Chips (Topic Explorer)
            _buildSectionTitle(isId ? 'Topik Pertanyaan' : 'Browse Topics'),
            _buildCategoryChips(isId),

            const SizedBox(height: 16),

            // 3. FAQ List Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionTitle(isId ? 'Pertanyaan Umum (FAQ)' : 'Frequently Asked Questions'),
                if (faqs.isNotEmpty)
                  Text(
                    '${faqs.length} ${isId ? 'jawaban' : 'answers'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
              ],
            ),

            // 4. FAQ Accordion Items
            if (_isLoading && _allFaqs.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: Color(0xFFDD2222)),
                ),
              )
            else if (faqs.isEmpty)
              _buildEmptyFaqState(isId)
            else
              ...faqs.map((item) => _buildFAQAccordionItem(item, isId)),

            const SizedBox(height: 5),

            // 5. Fallback CS WhatsApp Section (Placed at the bottom to filter casual taps)
            _buildBottomContactCard(isId),

            const SizedBox(height: 10),

            // 6. Social Media & Email Links
            _buildSocialCard(isId),

            const SizedBox(height: 15),
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildSearchBar(bool isId) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: isId
              ? 'Ketik masalah pesanan, refund, voucher, poin...'
              : 'Type order issues, refund, vouchers...',
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
          prefixIcon: const Icon(Icons.search, color: Color(0xFFDD2222), size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildCategoryChips(bool isId) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // All category chip
          ChoiceChip(
            label: Text(isId ? 'Semua' : 'All'),
            selected: _selectedCategoryId == null,
            onSelected: (selected) {
              if (selected) setState(() => _selectedCategoryId = null);
            },
            selectedColor: const Color(0xFFDD2222),
            labelStyle: TextStyle(
              color: _selectedCategoryId == null ? Colors.white : Colors.grey[800],
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            backgroundColor: Colors.white,
            side: BorderSide(
              color: _selectedCategoryId == null ? const Color(0xFFDD2222) : Colors.grey[300]!,
            ),
          ),
          const SizedBox(width: 8),

          // Dynamic categories
          ..._categories.map((cat) {
            final isSelected = _selectedCategoryId == cat.id;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(cat.localizedName(isId)),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() => _selectedCategoryId = selected ? cat.id : null);
                },
                selectedColor: const Color(0xFFDD2222),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[800],
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: isSelected ? const Color(0xFFDD2222) : Colors.grey[300]!,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFAQAccordionItem(HelpFaqItem item, bool isId) {
    final isExpanded = _expandedFaqId == item.id;
    final isRated = _ratedFaqIds.contains(item.id);
    final isUnhelpful = _unhelpfulFaqIds.contains(item.id);

    return Card(
      elevation: 1,
      surfaceTintColor: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setState(() {
                _expandedFaqId = isExpanded ? null : item.id;
              });
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.localizedQuestion(isId),
                      style: const TextStyle(
                        // fontWeight: FontWeight.w600,
                        fontSize: 14,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Text(
                    item.localizedAnswer(isId),
                    style: TextStyle(
                      color: Colors.grey[800],
                      height: 1.55,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Feedback Section
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isRated
                              ? (isId ? 'Terima kasih atas tanggapan Anda!' : 'Thank you for your feedback!')
                              : (isId ? 'Jawaban ini membantu?' : 'Answer helpful?'),
                          style: TextStyle(
                            fontSize: 11,
                            color: isRated ? Colors.green[800] : Colors.grey[600],
                            fontWeight: isRated ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        if (!isRated)
                          Row(
                            children: [
                              InkWell(
                                onTap: () => _handleFeedback(item.id, true, isId),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.grey[300]!),
                                  ),
                                  child: Text(isId ? '👍 Ya' : '👍 Yes', style: const TextStyle(fontSize: 11)),
                                ),
                              ),
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: () => _handleFeedback(item.id, false, isId),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.grey[300]!),
                                  ),
                                  child: Text(isId ? '👎 Tidak' : '👎 No', style: const TextStyle(fontSize: 11)),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),

                  // Smart WhatsApp Fallback Prompt if user voted "Tidak"
                  if (isUnhelpful)
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF25D366).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const FaIcon(FontAwesomeIcons.whatsapp, color: Color(0xFF25D366), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isId
                                  ? 'Belum menyelesaikan kendala Anda?'
                                  : 'Did not solve your issue?',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ),
                          TextButton(
                            onPressed: () => _handleWhatsAppTap(
                              _settings.whatsappNumber,
                              isId,
                              faqQuestion: item.localizedQuestion(isId),
                            ),
                            child: Text(
                              isId ? 'Tanya CS' : 'Ask CS',
                              style: const TextStyle(
                                color: Color(0xFF1EBE5D),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomContactCard(bool isId) {
    return Card(
      elevation: 2,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFDD2222).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.support_agent_rounded,
                color: Color(0xFFDD2222),
                size: 36,
              ),
            ),
            const SizedBox(height: 12),
            // Realtime operating hours status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _isWithinOperatingHours()
                    ? Colors.green.withValues(alpha: 0.12)
                    : Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: _isWithinOperatingHours() ? Colors.green[700] : Colors.amber[800],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isWithinOperatingHours()
                        ? (isId ? 'Layanan CS Sedang Online' : 'CS is Online')
                        : (isId ? 'Layanan CS Sedang Offline' : 'CS is Offline'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _isWithinOperatingHours() ? Colors.green[800] : Colors.amber[900],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isId ? 'Masalah belum terselesaikan?' : 'Still having issues?',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              isId
                  ? 'Tim Customer Service Delitopia siap membantu kendala Anda secara langsung pada ${_settings.localizedOperatingHours(isId)}.'
                  : 'Delitopia Customer Service team is ready to assist you during ${_settings.localizedOperatingHours(isId)}.',
              style: TextStyle(color: Colors.grey[600], fontSize: 12, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () => _handleWhatsAppTap(
                  _settings.whatsappNumber,
                  isId,
                ),
                label: Text(
                  isId ? 'Chat Customer Service' : 'Chat Customer Service',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 16),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyFaqState(bool isId) {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            isId
                ? 'Tidak ada pertanyaan yang sesuai'
                : 'No matching questions found',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            isId
                ? 'Coba gunakan kata kunci lain atau langsung hubungi tim Customer Service kami via WhatsApp.'
                : 'Try different keywords or contact our support directly via WhatsApp.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: () => _handleWhatsAppTap(_settings.whatsappNumber, isId),
            icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 16),
            label: Text(isId ? 'Tanya CS di WhatsApp' : 'Ask on WhatsApp'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialCard(bool isId) {
    return Card(
      elevation: 1,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildSocialButton(
              icon: Icons.web,
              label: 'Website',
              onTap: () => _launchExternalUrl(_settings.websiteUrl),
            ),
            _buildSocialButton(
              icon: FontAwesomeIcons.instagram,
              label: 'Instagram',
              onTap: () => _launchExternalUrl(_settings.instagramUrl),
            ),
            _buildSocialButton(
              icon: FontAwesomeIcons.tiktok,
              label: 'TikTok',
              onTap: () => _launchExternalUrl(_settings.tiktokUrl),
            ),
            _buildSocialButton(
              icon: Icons.email_outlined,
              label: 'Email',
              onTap: () => _launchEmail(
                _settings.supportEmail,
                subject: isId
                    ? 'Pertanyaan Layanan Delitopia'
                    : 'Delitopia Service Inquiry',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required dynamic icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFDD2222).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: icon is IconData
                  ? Icon(icon, color: const Color(0xFFDD2222), size: 18)
                  : FaIcon(icon, color: const Color(0xFFDD2222), size: 18),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Operating Hours Check & Dispatcher ---

  bool _isWithinOperatingHours() {
    try {
      final nowWib = DateTime.now().toUtc().add(const Duration(hours: 7));
      final text = _settings.operatingHoursId;
      final match = RegExp(r'(\d{1,2})[:.](\d{2})\s*[-–]\s*(\d{1,2})[:.](\d{2})').firstMatch(text);
      if (match != null) {
        final startH = int.parse(match.group(1)!);
        final startM = int.parse(match.group(2)!);
        final endH = int.parse(match.group(3)!);
        final endM = int.parse(match.group(4)!);

        final currentMins = nowWib.hour * 60 + nowWib.minute;
        final startMins = startH * 60 + startM;
        final endMins = endH * 60 + endM;

        return currentMins >= startMins && currentMins < endMins;
      }
      return nowWib.hour >= 9 && nowWib.hour < 16;
    } catch (_) {
      final nowWib = DateTime.now().toUtc().add(const Duration(hours: 7));
      return nowWib.hour >= 9 && nowWib.hour < 16;
    }
  }

  void _handleWhatsAppTap(String phone, bool isId, {String? faqQuestion}) {
    final isOpen = _isWithinOperatingHours();

    if (!isOpen) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.access_time_rounded, color: Colors.amber, size: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isId ? 'Layanan CS Sedang Tutup' : 'Support is Offline',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isId
                    ? 'Saat ini Anda berada di luar jam operasional Customer Service Delitopia.'
                    : 'You are currently contacting outside Delitopia Customer Service operating hours.',
                style: TextStyle(color: Colors.grey[800], fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _settings.localizedOperatingHours(isId),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isId
                    ? 'Anda tetap dapat mengirimkan pesan ke WhatsApp, namun pesan Anda akan dibalas oleh tim kami saat jam kerja dimulai kembali.'
                    : 'You can still send your message to WhatsApp, but our team will reply once working hours resume.',
                style: TextStyle(color: Colors.grey[600], fontSize: 12, height: 1.4),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                isId ? 'Tutup' : 'Close',
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                _launchWhatsAppWithContext(phone, isId, faqQuestion: faqQuestion);
              },
              icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 16),
              label: Text(isId ? 'Tetap Kirim Pesan' : 'Send Anyway'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      );
    } else {
      _launchWhatsAppWithContext(phone, isId, faqQuestion: faqQuestion);
    }
  }

  // --- External Launchers ---

  Future<void> _launchWhatsAppWithContext(
    String phone,
    bool isId, {
    String? faqQuestion,
  }) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    String text;
    if (faqQuestion != null && faqQuestion.isNotEmpty) {
      text = isId
          ? 'Halo CS Delitopia, saya sudah membaca Pusat Bantuan mengenai "$faqQuestion", namun masih membutuhkan bantuan lebih lanjut terkait akun/pesanan saya.'
          : 'Hello Delitopia Support, I read the FAQ regarding "$faqQuestion", but I still need further assistance regarding my account/order.';
    } else {
      text = isId
          ? 'Halo CS Delitopia, saya sudah membaca topik di Pusat Bantuan tetapi masih membutuhkan bantuan terkait layanan/pesanan Delitopia.'
          : 'Hello Delitopia Support, I checked the Help Center topics but still need help regarding Delitopia service/order.';
    }

    final waUrl = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(text)}');
    if (await canLaunchUrl(waUrl)) {
      await launchUrl(waUrl, mode: LaunchMode.externalApplication);
    } else {
      _showErrorSnackBar(isId ? 'Tidak dapat membuka aplikasi WhatsApp' : 'Could not launch WhatsApp');
    }
  }

  Future<void> _launchEmail(String email, {required String subject}) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty) return;
    final uri = Uri(
      scheme: 'mailto',
      path: cleanEmail,
      query: 'subject=${Uri.encodeComponent(subject)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      final isId = _isId(ref.read(appLanguageProvider));
      _showErrorSnackBar(isId ? 'Tidak dapat membuka aplikasi email' : 'Could not launch email app');
    }
  }

  Future<void> _launchExternalUrl(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  // Fallback FAQs if backend is offline
  List<HelpFaqItem> _fallbackFaqs() {
    return const [
      HelpFaqItem(
        id: 1,
        categoryId: 1,
        questionId: 'Bagaimana cara pesan makanan di Delitopia?',
        answerId:
            'Pilih outlet terlebih dahulu, cari menu, masukkan menu ke keranjang, lalu lanjut ke checkout. Anda bisa memilih tipe pesanan seperti dine in, take away, atau delivery jika tersedia.',
        questionEn: 'How do I place an order?',
        answerEn:
            'Select an outlet first, search menus, add to cart, and proceed to checkout. You can choose dine-in, take away, or delivery.',
        isPopular: true,
      ),
      HelpFaqItem(
        id: 2,
        categoryId: 1,
        questionId: 'Apa yang harus dilakukan jika pesanan saya kurang atau salah?',
        answerId:
            'Buka riwayat pesanan Anda dan laporkan kendala. Anda cukup melampirkan foto makanan yang salah langsung di chat WhatsApp untuk diproses refund atau penggantian tanpa repot.',
        questionEn: 'What if items are missing or incorrect?',
        answerEn:
            'Open your order history and report issue. Send a photo of the received items directly in WhatsApp for swift resolution or refund.',
        isPopular: true,
      ),
      HelpFaqItem(
        id: 3,
        categoryId: 2,
        questionId: 'Metode pembayaran apa saja yang tersedia?',
        answerId:
            'Aplikasi mendukung pembayaran QRIS (GoPay, OVO, Dana, ShopeePay, Mobile Banking) dan Tunai di kasir sesuai kebijakan outlet.',
        questionEn: 'What payment methods are available?',
        answerEn:
            'The app supports QRIS (GoPay, OVO, Dana, ShopeePay, Mobile Banking) and Cash at cashier.',
        isPopular: true,
      ),
      HelpFaqItem(
        id: 4,
        categoryId: 2,
        questionId: 'Bagaimana proses pengembalian dana (refund) untuk QRIS?',
        answerId:
            'Jika pesanan dibatalkan oleh pihak outlet, pengembalian dana QRIS akan diverifikasi langsung oleh CS kami. Hubungi WhatsApp CS resmi kami dengan mencantumkan Nomor Pesanan Anda.',
        questionEn: 'How does refund work for QRIS?',
        answerEn:
            'If an order is cancelled by the outlet, QRIS refund will be verified by CS. Contact our WhatsApp support with your Order Number.',
        isPopular: true,
      ),
      HelpFaqItem(
        id: 5,
        categoryId: 3,
        questionId: 'Kapan saya mendapatkan poin?',
        answerId:
            'Poin masuk otomatis setelah pesanan berstatus selesai dan lunas. Perhitungan standar yaitu Rp 1.000 subtotal belanja = 1 poin.',
        questionEn: 'When do I earn points?',
        answerEn:
            'Points are added automatically once the order is completed and paid. Every Rp 1,000 spend = 1 point.',
        isPopular: true,
      ),
      HelpFaqItem(
        id: 6,
        categoryId: 3,
        questionId: 'Bagaimana cara menggunakan voucher?',
        answerId:
            'Buka menu Voucher untuk melihat voucher yang tersedia. Voucher yang memenuhi syarat minimum pembelian dan brand dapat dipilih saat checkout.',
        questionEn: 'How do I use vouchers?',
        answerEn:
            'Open Vouchers tab to see available vouchers. Valid vouchers can be applied at checkout if minimum spend is met.',
        isPopular: true,
      ),
      HelpFaqItem(
        id: 7,
        categoryId: 1,
        questionId: 'Bagaimana cara membatalkan pesanan?',
        answerId:
            'Pesanan hanya bisa dibatalkan saat status masih Menunggu Pembayaran atau sebelum dapur mulai memasak pesanan.',
        questionEn: 'How do I cancel an order?',
        answerEn:
            'Orders can only be cancelled while pending payment or before kitchen starts cooking.',
        isPopular: false,
      ),
      HelpFaqItem(
        id: 8,
        categoryId: 4,
        questionId: 'Apa perbedaan login Google, nomor HP, dan email?',
        answerId:
            'Login Google menggunakan akun Google tanpa sandi. Login nomor HP menggunakan verifikasi OTP via WhatsApp/SMS. Login email dapat digunakan jika sudah membuat sandi.',
        questionEn: 'What is the difference between Google, Phone, and Email login?',
        answerEn:
            'Google login is passwordless. Phone login uses WhatsApp/SMS OTP. Email login requires password setup in profile.',
        isPopular: false,
      ),
    ];
  }
}
