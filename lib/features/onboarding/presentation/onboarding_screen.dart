import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/preferences_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../inspect/presentation/home_screen.dart';

class OnboardingPageData {
  final String title;
  final String description;
  final IconData icon;
  final Color accentColor;

  const OnboardingPageData({
    required this.title,
    required this.description,
    required this.icon,
    required this.accentColor,
  });
}

/// 3-Screen Onboarding Flow with Lagoon & Amber vector styling.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<OnboardingPageData> _pages = [
    OnboardingPageData(
      title: 'Paste a link',
      description:
          'Copy any public media link from your browser or apps. ClipVault auto-detects links from your clipboard instantly.',
      icon: Icons.link_rounded,
      accentColor: Color(0xFF0A6B6B), // Lagoon
    ),
    OnboardingPageData(
      title: 'Preview & choose quality',
      description:
          'Inspect titles, authors, and duration with full transparency. Select video resolutions from 360p to 1080p or audio-only.',
      icon: Icons.tune_rounded,
      accentColor: Color(0xFFFFAA1D), // Amber
    ),
    OnboardingPageData(
      title: 'Saved to your phone, fast',
      description:
          'Multi-connection speed engine downloads segments in parallel straight to your device gallery, music, and public storage.',
      icon: Icons.bolt_rounded,
      accentColor: Color(0xFF1E9E6A), // Semantic Mint
    ),
  ];

  Future<void> _completeOnboarding() async {
    HapticFeedback.mediumImpact();
    await ref.read(preferencesServiceProvider).setOnboardingDone(true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, anim1, anim2) => const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  void _nextPage() {
    HapticFeedback.lightImpact();
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isLastPage = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (!isLastPage)
            TextButton(
              onPressed: _completeOnboarding,
              style: TextButton.styleFrom(foregroundColor: colors.textSecondary),
              child: const Text('Skip', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Geometric Vector Illustration Container
                        _buildIllustration(colors, page),
                        const SizedBox(height: 36),
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: AppTypography.display(context).copyWith(
                            fontSize: 26,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          page.description,
                          textAlign: TextAlign.center,
                          style: AppTypography.body(context).copyWith(
                            color: colors.textSecondary,
                            fontSize: 15,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Bottom Action Bar with Dots & Next Button
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
              child: Column(
                children: [
                  // Dots indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (i) {
                      final isActive = i == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive ? colors.accent : colors.outline,
                          borderRadius: AppRadii.rPill,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  AppButton.accent(
                    label: isLastPage ? 'Get Started' : 'Continue',
                    isFullWidth: true,
                    onPressed: _nextPage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIllustration(AppColors colors, OnboardingPageData page) {
    return SizedBox(
      width: 180,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Lagoon Soft Glow Circle
          Container(
            width: 170,
            height: 170,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.primaryContainer.withValues(alpha: 0.5),
            ),
          ),
          // Angled Paper Surface Card
          Transform.rotate(
            angle: -0.06,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: AppRadii.r24,
                border: Border.all(color: colors.outline, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
            ),
          ),
          // Accent Icon Orb
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.accent,
              boxShadow: [
                BoxShadow(
                  color: colors.accent.withValues(alpha: 0.4),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              page.icon,
              size: 38,
              color: colors.onAccent,
            ),
          ),
        ],
      ),
    );
  }
}
