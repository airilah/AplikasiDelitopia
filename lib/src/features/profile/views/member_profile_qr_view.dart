import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/widgets/back_button_wrapper.dart';
import '../../../core/localization/app_language.dart';
import '../../../shared/models/member_profile_model.dart';
import '../../../shared/services/pos_service.dart';

class Particle {
  double x, y;
  double vx, vy;
  Color color;
  double size;
  double alpha = 1.0;
  
  Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
  });
}

class SparklePainter extends CustomPainter {
  final List<Particle> particles;
  SparklePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in particles) {
      paint.color = p.color.withValues(alpha: p.alpha);
      canvas.drawCircle(Offset(p.x, p.y), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class MemberProfileQrView extends ConsumerStatefulWidget {
  const MemberProfileQrView({super.key});

  @override
  ConsumerState<MemberProfileQrView> createState() => _MemberProfileQrViewState();
}

class _MemberProfileQrViewState extends ConsumerState<MemberProfileQrView> with TickerProviderStateMixin {
  late AnimationController _pointsController;
  late AnimationController _progressController;
  late AnimationController _floatingController;
  late AnimationController _bounceController;
  late AnimationController _levelUpController;

  int? _currentPoint;
  double? _currentSpent;
  String? _currentLevelName;

  double _pointsValue = 0;
  double _progressValue = 0;
  double _progressPercent = 0;
  String _levelNameDisplay = 'Bronze';
  String _progressLevelText = 'Bronze';
  double _nextLevelMinDisplay = 0;
  double _remainingAmountDisplay = 0;
  String? _selectedMilestoneLevelName;

  bool _showFloatingText = false;
  int _floatingDiff = 0;

  bool _showLevelUp = false;
  String _levelUpFrom = '';
  String _levelUpTo = '';
  double _levelUpPulse = 1.0;

  final List<Particle> _particles = [];
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _pointsController = AnimationController(vsync: this);
    _progressController = AnimationController(vsync: this);
    
    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _levelUpController = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _pointsController.dispose();
    _progressController.dispose();
    _floatingController.dispose();
    _bounceController.dispose();
    _levelUpController.dispose();
    super.dispose();
  }

  void _spawnParticles(double centerX, double centerY) {
    _particles.clear();
    final random = math.Random();
    final colors = [
      const Color(0xFFF5B400),
      const Color(0xFF8F9AA7),
      const Color(0xFF7C5FE6),
      const Color(0xFFDD2222),
      Colors.blue,
      Colors.green,
      Colors.orange,
    ];
    for (int i = 0; i < 90; i++) {
      final angle = random.nextDouble() * 2 * math.pi;
      final speed = 4.0 + random.nextDouble() * 10.0;
      _particles.add(Particle(
        x: centerX,
        y: centerY,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed - (2.0 + random.nextDouble() * 4.0),
        color: colors[random.nextInt(colors.length)],
        size: 3.5 + random.nextDouble() * 5.5,
      ));
    }
  }

  void _updateParticles() {
    for (final p in _particles) {
      p.x += p.vx;
      p.y += p.vy;
      p.vy += 0.20;
      p.vx *= 0.97;
      p.alpha = math.max(0.0, p.alpha - 0.015);
    }
    _particles.removeWhere((p) => p.alpha <= 0);
  }

  void _checkAndTriggerSync(MemberProfile profile) {
    if (_isAnimating) return;

    final progress = profile.levelProgress ??
        profile.user.levelProgress ??
        _fallbackProgress(profile.user);

    final newPoint = profile.user.point;
    final newSpent = progress.totalSpent;
    final newLevelName = progress.currentLevel.name;

    if (_currentPoint == null) {
      setState(() {
        _currentPoint = newPoint;
        _currentSpent = newSpent;
        _currentLevelName = newLevelName;

        _pointsValue = newPoint.toDouble();
        _progressValue = newSpent;
        _progressPercent = progress.percentage.clamp(0.0, 100.0).toDouble();
        _levelNameDisplay = newLevelName;
        _progressLevelText = progress.nextLevel == null
            ? newLevelName
            : '$newLevelName -> ${progress.nextLevel!.name}';
        _nextLevelMinDisplay = progress.nextLevel?.minPurchase ?? newSpent;
        _remainingAmountDisplay = progress.remainingAmount;
        _selectedMilestoneLevelName ??= progress.nextLevel?.name ?? newLevelName;
      });
      return;
    }

    if (newPoint != _currentPoint || newSpent != _currentSpent || newLevelName != _currentLevelName) {
      _startAnimationSequence(
        oldPoint: _currentPoint!,
        newPoint: newPoint,
        oldSpent: _currentSpent!,
        newSpent: newSpent,
        oldLevelName: _currentLevelName!,
        newLevelName: newLevelName,
        profile: profile,
        progress: progress,
      );
    }
  }

  Future<void> _startAnimationSequence({
    required int oldPoint,
    required int newPoint,
    required double oldSpent,
    required double newSpent,
    required String oldLevelName,
    required String newLevelName,
    required MemberProfile profile,
    required MemberLevelProgress progress,
  }) async {
    final size = MediaQuery.of(context).size;
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    setState(() {
      _isAnimating = true;
      _currentPoint = newPoint;
      _currentSpent = newSpent;
      _currentLevelName = newLevelName;
    });

    final levelChanged = oldLevelName.toLowerCase() != newLevelName.toLowerCase();

    if (newPoint > oldPoint) {
      setState(() {
        _floatingDiff = newPoint - oldPoint;
        _showFloatingText = true;
      });
      _floatingController.forward(from: 0.0);

      _pointsController.duration = const Duration(milliseconds: 1000);
      final pointsAnimation = Tween<double>(
        begin: oldPoint.toDouble(),
        end: newPoint.toDouble(),
      ).animate(CurvedAnimation(parent: _pointsController, curve: Curves.easeOut));

      _pointsController.addListener(() {
        setState(() {
          _pointsValue = pointsAnimation.value;
        });
      });

      await _pointsController.forward(from: 0.0);

      await _bounceController.forward(from: 0.0);
      await _bounceController.reverse();

      setState(() {
        _showFloatingText = false;
      });
    } else {
      setState(() {
        _pointsValue = newPoint.toDouble();
      });
    }

    if (newSpent > oldSpent) {
      _progressController.duration = const Duration(milliseconds: 1200);

      if (levelChanged) {
        final oldLevelLimit = progress.levels
            .firstWhere((l) => l.name.toLowerCase() == oldLevelName.toLowerCase(),
                orElse: () => progress.currentLevel)
            .minPurchase;

        final newLevelLimit = progress.levels
            .firstWhere((l) => l.name.toLowerCase() == newLevelName.toLowerCase(),
                orElse: () => progress.currentLevel)
            .minPurchase;

        final double oldLevelMin = oldLevelLimit;
        final double oldRange = math.max(1.0, newLevelLimit - oldLevelMin);

        final progressAnimation = Tween<double>(
          begin: oldSpent,
          end: newLevelLimit,
        ).animate(CurvedAnimation(parent: _progressController, curve: Curves.easeOut));

        _progressController.addListener(() {
          final val = progressAnimation.value;
          final pct = (((val - oldLevelMin) / oldRange) * 100).clamp(0.0, 100.0);
          setState(() {
            _progressValue = val;
            _progressPercent = pct;
            _remainingAmountDisplay = math.max(0.0, newLevelLimit - val);
          });
        });

        await _progressController.forward(from: 0.0);

        setState(() {
          _progressValue = newLevelLimit;
          _progressPercent = 100.0;
          _remainingAmountDisplay = 0.0;
        });

        setState(() {
          _levelUpFrom = oldLevelName;
          _levelUpTo = newLevelName;
          _showLevelUp = true;
        });

        _spawnParticles(centerX, centerY);

        void handleParticles() {
          setState(() {
            _updateParticles();
            _levelUpPulse = 1.0 + 0.1 * math.sin(_levelUpController.value * 2 * math.pi * 3);
          });
        }

        _levelUpController.addListener(handleParticles);
        _levelUpController.duration = const Duration(milliseconds: 3000);
        await _levelUpController.forward(from: 0.0);
        _levelUpController.removeListener(handleParticles);

        setState(() {
          _showLevelUp = false;
          _levelNameDisplay = newLevelName;
          _particles.clear();
        });

        _progressController.duration = const Duration(milliseconds: 1000);

        final nextLevel = progress.nextLevel;
        final nextMin = nextLevel?.minPurchase ?? newLevelLimit;
        final newRange = math.max(1.0, nextMin - newLevelLimit);

        setState(() {
          _progressLevelText = nextLevel == null ? newLevelName : '$newLevelName -> ${nextLevel.name}';
          _nextLevelMinDisplay = nextMin;
        });

        final nextProgressAnimation = Tween<double>(
          begin: newLevelLimit,
          end: newSpent,
        ).animate(CurvedAnimation(parent: _progressController, curve: Curves.easeOut));

        _progressController.addListener(() {
          final val = nextProgressAnimation.value;
          final pct = nextLevel == null ? 100.0 : (((val - newLevelLimit) / newRange) * 100).clamp(0.0, 100.0);
          setState(() {
            _progressValue = val;
            _progressPercent = pct;
            _remainingAmountDisplay = math.max(0.0, nextMin - val);
          });
        });

        await _progressController.forward(from: 0.0);
      } else {
        final nextLevel = progress.nextLevel;
        final currentMin = progress.currentLevel.minPurchase;
        final nextMin = nextLevel?.minPurchase ?? currentMin;
        final range = math.max(1.0, nextMin - currentMin);

        final progressAnimation = Tween<double>(
          begin: oldSpent,
          end: newSpent,
        ).animate(CurvedAnimation(parent: _progressController, curve: Curves.easeOut));

        _progressController.addListener(() {
          final val = progressAnimation.value;
          final pct = nextLevel == null ? 100.0 : (((val - currentMin) / range) * 100).clamp(0.0, 100.0);
          setState(() {
            _progressValue = val;
            _progressPercent = pct;
            _remainingAmountDisplay = math.max(0.0, nextMin - val);
          });
        });

        await _progressController.forward(from: 0.0);
      }
    } else {
      setState(() {
        _progressValue = newSpent;
        _progressPercent = progress.percentage.clamp(0.0, 100.0).toDouble();
        _progressLevelText = progress.nextLevel == null
            ? newLevelName
            : '$newLevelName -> ${progress.nextLevel!.name}';
        _nextLevelMinDisplay = progress.nextLevel?.minPurchase ?? newSpent;
        _remainingAmountDisplay = progress.remainingAmount;
        _levelNameDisplay = newLevelName;
      });
    }

    setState(() {
      _isAnimating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(memberProfileProvider);
    final lang = ref.watch(appLanguageProvider);

    return BackButtonWrapper(
      backRoute: '/navigation?index=4',
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        appBar: AppBar(
          leading: const AppBackButton(
            backRoute: '/navigation?index=4',
            color: Colors.white,
          ),
          title: Text(tr.get('my_member_profile', lang)),
          centerTitle: true,
          backgroundColor: const Color(0xFFDD2222),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Stack(
          children: [
            (() {
              if (profileAsync.hasValue && profileAsync.value != null) {
                final profile = profileAsync.value!;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _checkAndTriggerSync(profile);
                });
                return _buildProfileContent(context, profile, lang);
              }

              if (profileAsync.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (profileAsync.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          'Error: ${profileAsync.error}',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => ref.refresh(memberProfileProvider),
                          child: Text(tr.get('retry', lang)),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Center(child: Text(tr.get('failed_load_profile', lang)));
            })(),

            if (_showLevelUp)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.55),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: SparklePainter(_particles),
                            ),
                          ),
                          ScaleTransition(
                            scale: Tween<double>(begin: 0.5, end: 1.25)
                                .animate(CurvedAnimation(
                                  parent: _levelUpController,
                                  curve: const Interval(0.0, 0.45, curve: Curves.elasticOut),
                                )),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: _getLevelColor(_levelUpTo).withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: _getLevelColor(_levelUpTo).withValues(alpha: 0.4),
                                        blurRadius: 30,
                                        spreadRadius: 6,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.workspace_premium_rounded,
                                    color: _getLevelColor(_levelUpTo),
                                    size: 84,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                  'LEVEL UP!',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 30,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 3,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black45,
                                        blurRadius: 10,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(99),
                                    border: Border.all(color: Colors.white38),
                                  ),
                                  child: Text(
                                    '$_levelUpFrom ➔ $_levelUpTo',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileContent(
    BuildContext context,
    MemberProfile profile,
    AppLanguage lang,
  ) {
    final width = MediaQuery.of(context).size.width;
    final qrSize = math.min(width - 118, 252).clamp(180.0, 252.0).toDouble();

    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 16, bottom: 94),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFDD2222), Color(0xFFC51414)],
              ),
            ),
            child: Column(
              children: [
                Text(
                  tr.get('show_qr_to_cashier', lang),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  tr.get('scan_for_rewards', lang),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -74),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildQrCard(context, profile, qrSize, lang),
                  const SizedBox(height: 18),
                  _buildInfoCard(context, profile, lang),
                  const SizedBox(height: 14),
                  _buildStatsRow(context, profile),
                  const SizedBox(height: 14),
                  _buildProgressCard(context, profile, lang),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrCard(
    BuildContext context,
    MemberProfile profile,
    double qrSize,
    AppLanguage lang,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 26, 16, 26),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFF3F4F6)),
            ),
            child: QrImageView(
              data: profile.user.memberCode,
              version: QrVersions.auto,
              size: qrSize,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF111827),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF111827),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            lang == AppLanguage.indonesia ? 'Kode Member' : 'Member Code',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    profile.user.memberCode,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: Color(0xFF111827),
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _copyCode(context, profile.user.memberCode, lang),
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.copy_rounded,
                    size: 24,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    MemberProfile profile,
    AppLanguage lang,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _buildInfoRow(
            context,
            Icons.person_outline_rounded,
            lang == AppLanguage.indonesia ? 'Nama' : 'Name',
            profile.user.name.isEmpty ? '-' : profile.user.name,
          ),
          const Divider(height: 24),
          _buildInfoRow(
            context,
            Icons.phone_rounded,
            lang == AppLanguage.indonesia ? 'No. Telp' : 'Phone',
            profile.user.phoneNumber.isEmpty
                ? '-'
                : _maskPhoneNumber(profile.user.phoneNumber),
          ),
          const Divider(height: 24),
          _buildInfoRow(
            context,
            Icons.mail_outline_rounded,
            lang == AppLanguage.indonesia ? 'Email' : 'Email',
            profile.user.email.isEmpty ? '-' : profile.user.email,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, MemberProfile profile) {
    final lang = ref.watch(appLanguageProvider);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Row(
          children: [
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ScaleTransition(
                    scale: Tween<double>(begin: 1.0, end: 1.22)
                        .animate(CurvedAnimation(
                          parent: _bounceController,
                          curve: Curves.elasticOut,
                        )),
                    child: _buildStatCard(
                      label: lang == AppLanguage.indonesia ? 'Poin' : 'Points',
                      value: _pointsValue.round().toString(),
                      icon: Icons.star_rounded,
                      color: const Color(0xFFF5B400),
                      background: const Color(0xFFFFF8DF),
                    ),
                  ),
                  
                  if (_showFloatingText)
                    AnimatedBuilder(
                      animation: _floatingController,
                      builder: (context, child) {
                        return Positioned(
                          top: 15.0 - (42.0 * _floatingController.value),
                          left: 0,
                          right: 0,
                          child: Opacity(
                            opacity: (1.0 - _floatingController.value).clamp(0.0, 1.0),
                            child: Center(
                              child: Text(
                                '+$_floatingDiff ${lang == AppLanguage.indonesia ? 'Poin' : 'Points'}',
                                style: const TextStyle(
                                  color: Color(0xFFDD2222),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  shadows: [
                                    Shadow(
                                      color: Colors.white,
                                      blurRadius: 4,
                                      offset: Offset(0, 1.5),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Transform.scale(
                scale: _showLevelUp ? _levelUpPulse : 1.0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: _showLevelUp
                        ? [
                            BoxShadow(
                              color: _getLevelColor(_levelNameDisplay).withValues(alpha: 0.65),
                              blurRadius: 24,
                              spreadRadius: 5,
                            ),
                          ]
                        : [],
                  ),
                  child: _buildStatCard(
                    label: 'Level',
                    value: _levelNameDisplay,
                    icon: Icons.emoji_events_rounded,
                    color: _getLevelColor(_levelNameDisplay),
                    background: const Color(0xFFFBF7F4),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProgressCard(
    BuildContext context,
    MemberProfile profile,
    AppLanguage lang,
  ) {
    final progress = profile.levelProgress ??
        profile.user.levelProgress ??
        _fallbackProgress(profile.user);

    final levels = progress.levels.isEmpty ? _defaultLevels() : progress.levels;
    final activeTargetName = _selectedMilestoneLevelName ??
        (progress.nextLevel?.name ?? progress.currentLevel.name);
    final selectedLevel = levels.firstWhere(
      (l) => l.name.toLowerCase() == activeTargetName.toLowerCase(),
      orElse: () => levels.first,
    );

    final double currentSpent = _progressValue;
    final double targetMin = selectedLevel.minPurchase;
    final bool isReached = targetMin <= currentSpent;

    final double displayPercent = _isAnimating
        ? _progressPercent
        : (isReached
            ? 100.0
            : ((currentSpent / (targetMin > 0 ? targetMin : 1.0)) * 100)
                .clamp(0.0, 100.0));

    final double displayRemaining = _isAnimating
        ? _remainingAmountDisplay
        : (isReached ? 0.0 : math.max(0.0, targetMin - currentSpent));

    final String displaySubtitle = _isAnimating
        ? _progressLevelText
        : (isReached
            ? (lang == AppLanguage.indonesia
                ? '${selectedLevel.name} • Level Tercapai ✓'
                : '${selectedLevel.name} • Level Reached ✓')
            : '${progress.currentLevel.name} -> ${selectedLevel.name}');

    final String displayTargetText = _isAnimating
        ? (progress.nextLevel == null
            ? _formatCurrency(_progressValue)
            : '${_formatCurrency(_progressValue)} / ${_formatCurrency(_nextLevelMinDisplay)}')
        : '${_formatCurrency(currentSpent)} / ${_formatCurrency(targetMin)}';

    final String displayNote = _isAnimating
        ? (progress.nextLevel == null
            ? (lang == AppLanguage.indonesia
                ? 'Kamu sudah mencapai level tertinggi.'
                : 'You have reached the highest level.')
            : (lang == AppLanguage.indonesia
                ? 'Belanja lagi ${_formatCurrency(_remainingAmountDisplay)} untuk naik ke ${_progressLevelText.split('->').last.trim()}'
                : 'Spend ${_formatCurrency(_remainingAmountDisplay)} more to reach ${_progressLevelText.split('->').last.trim()}'))
        : (isReached
            ? (lang == AppLanguage.indonesia
                ? 'Kamu sudah memenuhi syarat untuk level ${selectedLevel.name}.'
                : 'You have reached the requirements for ${selectedLevel.name}.')
            : (lang == AppLanguage.indonesia
                ? 'Belanja lagi ${_formatCurrency(displayRemaining)} untuk naik ke ${selectedLevel.name}'
                : 'Spend ${_formatCurrency(displayRemaining)} more to reach ${selectedLevel.name}'));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFE8E8),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.trending_up_rounded,
                  color: Color(0xFFDD2222),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Membership Progress',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF111827),
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      displaySubtitle,
                      style: const TextStyle(
                        color: Color(0xFF4B5563),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                '${displayPercent.round()}%',
                style: const TextStyle(
                  color: Color(0xFF111827),
                ),
              ),
              const Spacer(),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    displayTargetText,
                    style: const TextStyle(
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(
                begin: (displayPercent / 100).clamp(0.0, 1.0),
                end: (displayPercent / 100).clamp(0.0, 1.0),
              ),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 10,
                backgroundColor: const Color(0xFFE5E7EB),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFFDD2222)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            displayNote,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 11,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          _buildLevelMilestones(progress, activeTargetName),
        ],
      ),
    );
  }

  Widget _buildLevelMilestones(
    MemberLevelProgress progress,
    String activeTargetName,
  ) {
    final levels = progress.levels.isEmpty ? _defaultLevels() : progress.levels;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDEDED)),
      ),
      child: Row(
        children: [
          for (final level in levels) ...[
            Expanded(
              child: _buildMilestoneItem(
                level,
                reached: level.minPurchase <= _progressValue,
                isSelected: level.name.toLowerCase() == activeTargetName.toLowerCase(),
                onTap: () {
                  setState(() {
                    _selectedMilestoneLevelName = level.name;
                  });
                },
              ),
            ),
            if (level != levels.last)
              const SizedBox(
                width: 10,
                child: Divider(
                  color: Color(0xFFD1D5DB),
                  thickness: 1,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildMilestoneItem(
    UserLevel level, {
    required bool reached,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final color = _getLevelColor(level.name);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        constraints: const BoxConstraints(minHeight: 82),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: isSelected
            ? BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              )
            : BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.workspace_premium_rounded,
              color: (reached || isSelected) ? color : const Color(0xFF9CA3AF),
              size: 25,
            ),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                level.name,
                maxLines: 1,
                style: TextStyle(
                  color: isSelected ? color : const Color(0xFF111827),
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _formatCurrency(level.minPurchase),
                maxLines: 1,
                style: TextStyle(
                  color: isSelected
                      ? color.withValues(alpha: 0.85)
                      : const Color(0xFF6B7280),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: Color(0xFFFFE8E8),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 22, color: const Color(0xFFDD2222)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value.isEmpty ? '-' : value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF4B5563),
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required Color background,
  }) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 84),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF4B5563),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.045),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  MemberLevelProgress _fallbackProgress(MemberProfileUser user) {
    final levels = _defaultLevels();
    final spent = user.totalSpent;
    final current = levels
        .where((level) => level.minPurchase <= spent)
        .fold<UserLevel>(levels.first, (previous, level) => level);
    UserLevel? next;
    for (final level in levels) {
      if (level.minPurchase > spent) {
        next = level;
        break;
      }
    }
    final range = next == null
        ? 1.0
        : math.max(1.0, next.minPurchase - current.minPurchase);
    final percent = next == null
        ? 100.0
        : (((spent - current.minPurchase) / range) * 100)
            .clamp(0.0, 100.0)
            .toDouble();

    return MemberLevelProgress(
      currentLevel: current,
      nextLevel: next,
      totalSpent: spent,
      percentage: percent,
      remainingAmount: next == null ? 0 : math.max(0, next.minPurchase - spent),
      levels: levels,
    );
  }

  List<UserLevel> _defaultLevels() {
    return [
      UserLevel(id: 1, name: 'Bronze', minPurchase: 0),
      UserLevel(id: 2, name: 'Silver', minPurchase: 1000000),
      UserLevel(id: 3, name: 'Gold', minPurchase: 2000000),
      UserLevel(id: 4, name: 'Platinum', minPurchase: 4000000),
    ];
  }

  Color _getLevelColor(String level) {
    switch (level.toLowerCase()) {
      case 'gold':
        return const Color(0xFFF5B400);
      case 'silver':
        return const Color(0xFF8F9AA7);
      case 'platinum':
        return const Color(0xFF7C5FE6);
      case 'bronze':
      default:
        return const Color(0xFFA15A2A);
    }
  }

  String _maskPhoneNumber(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7) return phone;

    final localNumber =
        digits.startsWith('62') ? '0${digits.substring(2)}' : digits;
    if (localNumber.length <= 7) return localNumber;

    return '${localNumber.substring(0, 4)}********${localNumber.substring(localNumber.length - 3)}';
  }

  String _formatCurrency(double value) {
    final rounded = value.round().toString();
    final formatted = rounded.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
    return 'Rp $formatted';
  }

  void _copyCode(BuildContext context, String code, AppLanguage lang) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(tr.get('code_copied_msg', lang).replaceAll('{code}', code)),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
