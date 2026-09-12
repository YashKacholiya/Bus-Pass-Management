// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icem_bus/config/routes/app_routes.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:icem_bus/services/storage/storage_service.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingModel> _slides = [
    OnboardingModel(
      title: 'Smart Digital Pass',
      description: 'Ditch paper passes! Carry your secure, QR-coded student bus pass directly on your smartphone for quick boarding.',
      painter: DigitalPassPainter(),
    ),
    OnboardingModel(
      title: 'Real-time Tracking',
      description: 'Stay updated! Track your designated bus route and estimated arrival times in real-time, preventing long campus waits.',
      painter: RouteTrackingPainter(),
    ),
    OnboardingModel(
      title: 'Instant Renewals',
      description: 'Pay on the go! Renew your bus pass instantly using built-in digital payments, with immediate admin verification.',
      painter: SecurePaymentPainter(),
    ),
  ];

  Future<void> _completeOnboarding() async {
    // Set onboarding as completed in SharedPreferences
    await ref.read(storageServiceProvider).setOnboardingCompleted(true);
    if (mounted) {
      context.go(AppRoutes.login);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (_currentPage < _slides.length - 1)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton(
                onPressed: _completeOnboarding,
                child: const Text('Skip'),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Page Slider
            Expanded(
              flex: 5,
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Custom Painter Illustration
                        Expanded(
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: 1.0,
                              child: Container(
                                margin: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.lightCrimson.withOpacity(0.4),
                                  shape: BoxShape.circle,
                                ),
                                child: CustomPaint(
                                  painter: slide.painter,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Title
                        Text(
                          slide.title,
                          style: theme.textTheme.displayMedium?.copyWith(
                            color: AppColors.primaryCrimson,
                            fontWeight: FontWeight.w800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        // Description
                        Text(
                          slide.description,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Pagination Controls & Actions
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Dynamic Indicator Dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _slides.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.only(right: 8),
                          height: 8,
                          width: _currentPage == index ? 24 : 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? AppColors.primaryCrimson
                                : AppColors.textLight.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Action Button (Next or Get Started)
                    ElevatedButton(
                      onPressed: () {
                        if (_currentPage == _slides.length - 1) {
                          _completeOnboarding();
                        } else {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        _currentPage == _slides.length - 1
                            ? 'Get Started'
                            : 'Next Route',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper model for Onboarding slides
class OnboardingModel {
  final String title;
  final String description;
  final CustomPainter painter;

  const OnboardingModel({
    required this.title,
    required this.description,
    required this.painter,
  });
}

// ==========================================
// CUSTOM VECTOR ART PAINTERS FOR AESTHETICS
// ==========================================

/// Slide 1 Painter: Smart Digital Pass (Phone, Digital Card, Ticket Mockup)
class DigitalPassPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint crimsonPaint = Paint()
      ..color = AppColors.primaryCrimson
      ..style = PaintingStyle.fill;

    final Paint goldPaint = Paint()
      ..color = AppColors.accentGold
      ..style = PaintingStyle.fill;

    final Paint phonePaint = Paint()
      ..color = AppColors.secondaryDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0;

    final double cx = size.width / 2;
    final double cy = size.height / 2;

    // Draw Mock Smartphone Outline
    final Rect phoneRect = Rect.fromCenter(center: Offset(cx, cy), width: 120, height: 210);
    canvas.drawRRect(RRect.fromRectAndRadius(phoneRect, const Radius.circular(16)), phonePaint);

    // Smartphone Screen Notch
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy - 95), width: 36, height: 12),
        const Radius.circular(6),
      ),
      phonePaint..style = PaintingStyle.fill,
    );

    // Floating Digital Pass Card
    final Rect cardRect = Rect.fromCenter(center: Offset(cx + 15, cy + 10), width: 120, height: 80);
    final Paint cardBgPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    // Draw card shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(cardRect.shift(const Offset(4, 4)), const Radius.circular(10)),
      Paint()..color = Colors.black.withOpacity(0.12)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(cardRect, const Radius.circular(10)),
      cardBgPaint,
    );
    
    // Draw card border
    canvas.drawRRect(
      RRect.fromRectAndRadius(cardRect, const Radius.circular(10)),
      Paint()
        ..color = AppColors.primaryCrimson.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Crimson Header Stripe on Card
    final Rect stripeRect = Rect.fromLTWH(cx - 45, cy - 30, 120, 20);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        stripeRect,
        topLeft: const Radius.circular(10),
        topRight: const Radius.circular(10),
      ),
      crimsonPaint..style = PaintingStyle.fill,
    );

    // Pass details (stub lines)
    final Paint linePaint = Paint()
      ..color = AppColors.textLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawLine(Offset(cx - 35, cy + 5), Offset(cx + 10, cy + 5), linePaint);
    canvas.drawLine(Offset(cx - 35, cy + 15), Offset(cx - 5, cy + 15), linePaint);

    // Mini Gold Pass Circle (representing pass status)
    canvas.drawCircle(Offset(cx + 35, cy + 28), 12, goldPaint);
    
    // Tiny Checkmark in Gold circle
    final Paint checkPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx + 30, cy + 28), Offset(cx + 34, cy + 32), checkPaint);
    canvas.drawLine(Offset(cx + 34, cy + 32), Offset(cx + 42, cy + 24), checkPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Slide 2 Painter: Route Tracking (Winding Path, Bus Icon, GPS Locator)
class RouteTrackingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;

    // Draw GPS pulsing circles
    final Paint pulsePaint = Paint()
      ..color = AppColors.primaryCrimson.withOpacity(0.08)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), 100, pulsePaint);
    canvas.drawCircle(Offset(cx, cy), 70, pulsePaint..color = AppColors.primaryCrimson.withOpacity(0.12));

    // Winding path (dashed)
    final Path path = Path();
    path.moveTo(cx - 70, cy + 60);
    path.cubicTo(cx - 40, cy + 70, cx - 20, cy - 20, cx, cy);
    path.cubicTo(cx + 20, cy + 20, cx + 50, cy - 60, cx + 70, cy - 40);

    final Paint pathPaint = Paint()
      ..color = AppColors.secondaryDark.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    
    canvas.drawPath(path, pathPaint);

    // Draw Pin locator on top right
    final Paint pinPaint = Paint()
      ..color = AppColors.primaryCrimson
      ..style = PaintingStyle.fill;
    
    final double pinX = cx + 70;
    final double pinY = cy - 40;
    
    // Draw Pin Drop Shape
    final Path pinPath = Path();
    pinPath.moveTo(pinX, pinY);
    pinPath.cubicTo(pinX - 10, pinY - 10, pinX - 12, pinY - 22, pinX, pinY - 30);
    pinPath.cubicTo(pinX + 12, pinY - 30, pinX + 10, pinY - 10, pinX, pinY);
    canvas.drawPath(pinPath, pinPaint);
    canvas.drawCircle(Offset(pinX, pinY - 20), 4, Paint()..color = Colors.white);

    // Draw Bus Icon floating in middle
    final Rect busRect = Rect.fromCenter(center: Offset(cx - 15, cy + 10), width: 44, height: 32);
    final Paint busPaint = Paint()
      ..color = AppColors.primaryCrimson
      ..style = PaintingStyle.fill;
    
    // Bus shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(busRect.shift(const Offset(2, 2)), const Radius.circular(6)),
      Paint()..color = Colors.black.withOpacity(0.15)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0),
    );
    // Bus Body
    canvas.drawRRect(
      RRect.fromRectAndRadius(busRect, const Radius.circular(6)),
      busPaint,
    );
    // Bus Windshield
    final Rect windowRect = Rect.fromLTWH(cx - 32, cy - 2, 10, 10);
    canvas.drawRect(windowRect, Paint()..color = Colors.white.withOpacity(0.7));
    // Side Windows
    canvas.drawRect(Rect.fromLTWH(cx - 18, cy - 2, 8, 10), Paint()..color = Colors.white.withOpacity(0.7));
    canvas.drawRect(Rect.fromLTWH(cx - 6, cy - 2, 8, 10), Paint()..color = Colors.white.withOpacity(0.7));

    // Wheels
    canvas.drawCircle(Offset(cx - 26, cy + 26), 5, Paint()..color = AppColors.secondaryDark);
    canvas.drawCircle(Offset(cx - 4, cy + 26), 5, Paint()..color = AppColors.secondaryDark);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Slide 3 Painter: Secure Payments (Shield, Card, Checkmark)
class SecurePaymentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;

    // Draw decorative background circles
    canvas.drawCircle(
      Offset(cx, cy),
      85,
      Paint()
        ..color = AppColors.accentGold.withOpacity(0.06)
        ..style = PaintingStyle.fill,
    );

    // Draw credit card back drop
    final Rect cardRect = Rect.fromCenter(center: Offset(cx - 15, cy - 15), width: 110, height: 70);
    final Paint cardPaint = Paint()
      ..color = AppColors.secondaryDark
      ..style = PaintingStyle.fill;
    
    // Draw shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(cardRect.shift(const Offset(3, 3)), const Radius.circular(8)),
      Paint()..color = Colors.black.withOpacity(0.1)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(cardRect, const Radius.circular(8)),
      cardPaint,
    );
    
    // Card Gold Chip
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx - 60, cy - 40, 18, 14), const Radius.circular(3)),
      Paint()..color = AppColors.accentGold,
    );

    // Shield of security in foreground
    final double sx = cx + 25;
    final double sy = cy + 15;
    
    // Shield Shadow
    final Path shieldPath = Path();
    shieldPath.moveTo(sx, sy - 30);
    shieldPath.quadraticBezierTo(sx + 24, sy - 30, sx + 25, sy - 20);
    shieldPath.quadraticBezierTo(sx + 25, sy + 10, sx, sy + 30);
    shieldPath.quadraticBezierTo(sx - 25, sy + 10, sx - 25, sy - 20);
    shieldPath.quadraticBezierTo(sx - 24, sy - 30, sx, sy - 30);
    
    canvas.drawPath(
      shieldPath.shift(const Offset(3, 3)),
      Paint()..color = Colors.black.withOpacity(0.15)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0),
    );

    // Shield Body
    canvas.drawPath(
      shieldPath,
      Paint()..color = Colors.white..style = PaintingStyle.fill,
    );
    
    // Inner Crimson Shield
    canvas.drawPath(
      shieldPath,
      Paint()
        ..color = AppColors.primaryCrimson
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5,
    );

    // Inner checkmark in Shield
    final Paint checkPaint = Paint()
      ..color = AppColors.primaryCrimson
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(sx - 9, sy - 2), Offset(sx - 2, sy + 6), checkPaint);
    canvas.drawLine(Offset(sx - 2, sy + 6), Offset(sx + 10, sy - 8), checkPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
