import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/localization/app_language.dart';

class InAppLiveTrackingView extends ConsumerStatefulWidget {
  final String trackUrl;
  final String orderNumber;
  final String? driverName;
  final String? driverPhone;
  final String? driverPlate;

  const InAppLiveTrackingView({
    super.key,
    required this.trackUrl,
    required this.orderNumber,
    this.driverName,
    this.driverPhone,
    this.driverPlate,
  });

  @override
  ConsumerState<InAppLiveTrackingView> createState() =>
      _InAppLiveTrackingViewState();
}

class _InAppLiveTrackingViewState extends ConsumerState<InAppLiveTrackingView> {
  late final WebViewController _controller;
  int _loadingProgress = 0;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) {
              setState(() {
                _loadingProgress = progress;
              });
            }
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _loadingProgress = 0;
                _hasError = false;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _loadingProgress = 100;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            // Only flag error if it's main frame
            if (error.isForMainFrame ?? true) {
              if (mounted) {
                setState(() {
                  _hasError = true;
                  _errorMessage = error.description;
                });
              }
            }
          },
        ),
      );

    final uri = Uri.tryParse(widget.trackUrl);
    if (uri != null) {
      _controller.loadRequest(uri);
    }
  }

  void _reloadPage() {
    setState(() {
      _hasError = false;
      _loadingProgress = 0;
    });
    final uri = Uri.tryParse(widget.trackUrl);
    if (uri != null) {
      _controller.loadRequest(uri);
    }
  }

  Future<void> _openInExternalBrowser() async {
    final uri = Uri.tryParse(widget.trackUrl);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _callDriver() async {
    if (widget.driverPhone == null || widget.driverPhone!.isEmpty) return;
    final uri = Uri.parse('tel:${widget.driverPhone}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);
    final isIndo = lang == AppLanguage.indonesia;
    final hasDriver =
        widget.driverName != null && widget.driverName!.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFDD2222),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: isIndo ? 'Kembali' : 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isIndo ? 'Lacak Kurir GrabExpress' : 'Track GrabExpress Courier',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (widget.orderNumber.isNotEmpty)
              Text(
                '#${widget.orderNumber}',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w400,
                  color: Colors.white70,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: isIndo ? 'Muat Ulang' : 'Reload',
            onPressed: _reloadPage,
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser_rounded),
            tooltip: isIndo ? 'Buka di Browser' : 'Open in Browser',
            onPressed: _openInExternalBrowser,
          ),
        ],
        bottom: _loadingProgress < 100 && !_hasError
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3.0),
                child: LinearProgressIndicator(
                  value: _loadingProgress / 100.0,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 3.0,
                ),
              )
            : null,
      ),
      body: Stack(
        children: [
          if (_hasError)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.wifi_off_rounded,
                        color: Color(0xFFDD2222),
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isIndo
                          ? 'Gagal Memuat Peta Pelacakan'
                          : 'Failed to Load Tracking Map',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage ??
                          (isIndo
                              ? 'Pastikan koneksi internet Anda aktif dan stabil.'
                              : 'Please make sure your internet connection is active and stable.'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _openInExternalBrowser,
                          icon: const Icon(Icons.open_in_browser_rounded,
                              size: 18),
                          label: Text(
                            isIndo ? 'Buka di Browser' : 'Open in Browser',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFDD2222),
                            side: const BorderSide(color: Color(0xFFDD2222)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _reloadPage,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: Text(isIndo ? 'Coba Lagi' : 'Try Again'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDD2222),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          else
            WebViewWidget(controller: _controller),

          // Bottom quick driver contact bar (floating above webview if driver available)
          if (hasDriver)
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF00B14F).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Image.asset(
                        'assets/icons/grab.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.driverName!,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.driverPlate != null &&
                              widget.driverPlate!.isNotEmpty)
                            Text(
                              widget.driverPlate!,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475569),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (widget.driverPhone != null &&
                        widget.driverPhone!.isNotEmpty)
                      IconButton.filled(
                        onPressed: _callDriver,
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF00B14F),
                          foregroundColor: Colors.white,
                          shape: const CircleBorder(),
                        ),
                        icon: const Icon(Icons.phone_rounded, size: 16),
                        tooltip: isIndo ? 'Hubungi Driver' : 'Call Driver',
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
