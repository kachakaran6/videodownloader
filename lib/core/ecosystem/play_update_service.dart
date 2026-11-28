import 'dart:io';
import 'package:flutter/material.dart';
import '../services/play_update_service.dart' as native_playcore;

/// Service managing native Google Play In-App Updates with lifecycle-safe execution.
///
/// Features:
/// - Uses official Google Play Core native APIs via MethodChannel.
/// - Never crashes on startup, network failure, sideload, or unowned build.
/// - Safe 30-minute cooldown on automatic checks to prevent rapid repeated queries.
/// - Full background download management with native restart snackbar.
class PlayUpdateService {
  static final PlayUpdateService _instance = PlayUpdateService._internal();
  factory PlayUpdateService() => _instance;
  PlayUpdateService._internal();

  bool _isChecking = false;
  DateTime? _lastAutoCheckTime;
  static const Duration _autoCheckCooldown = Duration(minutes: 30);

  /// Automatically checks for updates during app startup or app resumption.
  /// Throttled by cooldown to prevent repeated prompts on rapid app switching.
  Future<void> checkUpdateOnLifecycleResume() async {
    if (!Platform.isAndroid) return;

    final now = DateTime.now();
    if (_lastAutoCheckTime != null && now.difference(_lastAutoCheckTime!) < _autoCheckCooldown) {
      return;
    }

    if (_isChecking) return;
    _isChecking = true;

    try {
      _lastAutoCheckTime = DateTime.now();
      await native_playcore.PlayUpdateService.checkForUpdate(immediate: false);
    } catch (e) {
      debugPrint('[PlayUpdateService] Lifecycle update check skipped or failed gracefully: $e');
    } finally {
      _isChecking = false;
    }
  }

  /// Manually checks for update from Settings. Shows user feedback if up-to-date or unavailable.
  Future<void> checkForUpdateManual(BuildContext context) async {
    if (!Platform.isAndroid) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('In-app updates are only supported on Android.')),
        );
      }
      return;
    }

    if (_isChecking) return;
    _isChecking = true;

    try {
      final isAvailable = await native_playcore.PlayUpdateService.checkForUpdate(immediate: false);
      if (!isAvailable && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You are using the latest version of ClipVault.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('[PlayUpdateService] Manual check failed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to reach Google Play Store. Please check your connection.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      _isChecking = false;
    }
  }
}
