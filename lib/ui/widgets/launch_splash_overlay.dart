import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../screens/Settings/settings_screen_controller.dart';

class LaunchSplashOverlay extends StatefulWidget {
  final Widget child;

  const LaunchSplashOverlay({super.key, required this.child});

  @override
  State<LaunchSplashOverlay> createState() => _LaunchSplashOverlayState();
}

class _LaunchSplashOverlayState extends State<LaunchSplashOverlay>
    with SingleTickerProviderStateMixin {
  bool _isVisible = true;
  double _opacity = 1.0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Keep splash visible briefly then fade out smoothly
    _timer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) {
        setState(() {
          _opacity = 0.0;
        });
        Timer(const Duration(milliseconds: 350), () {
          if (mounted) {
            setState(() {
              _isVisible = false;
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) {
      return widget.child;
    }

    String currentVersion = "v2.0.0";
    if (Get.isRegistered<SettingsScreenController>()) {
      final ver = Get.find<SettingsScreenController>().currentVersion;
      if (ver.isNotEmpty) {
        currentVersion = ver.startsWith('v') ? ver : "v$ver";
      }
    }

    return Stack(
      children: [
        widget.child,
        AnimatedOpacity(
          opacity: _opacity,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          child: Container(
            color: const Color(0xFF0D0F17),
            width: double.infinity,
            height: double.infinity,
            child: SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Official Rhythm Music Logo
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withOpacity(0.18),
                            blurRadius: 32,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/icons/icon.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 22),
                    // Latest Version Pill Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF6366F1).withOpacity(0.35),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withOpacity(0.1),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "$currentVersion • Latest Version",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                              decoration: TextDecoration.none,
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
    );
  }
}
