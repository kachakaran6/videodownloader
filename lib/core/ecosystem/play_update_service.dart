import 'dart:io';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

/// Service managing native Google Play In-App Updates with lifecycle-safe execution.
///
/// Strict rules:
/// - Uses the official Google Play In-App Updates API exclusively via `in_app_update`.
/// - Never shows a custom dialog, sheet, or imitation UI.
/// - Recovers in-progress immediate updates upon app resumption.
/// - Implements cooldowns to prevent duplicate prompts during repeated lifecycle events.
/// - Gracefully catches and handles offline, sideload, emulator, and Play Core exceptions.
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
      final updateInfo = await InAppUpdate.checkForUpdate();
      _lastAutoCheckTime = DateTime.now();

      // 1. Resume in-progress immediate update if interrupted
      if (updateInfo.updateAvailability == UpdateAvailability.developerTriggeredUpdateInProgress) {
        debugPrint('[PlayUpdateService] Resuming in-progress immediate update...');
        await InAppUpdate.performImmediateUpdate();
        return;
      }

      // 2. Check for newly available update
      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        debugPrint('[PlayUpdateService] Update available! Priority: ${updateInfo.updatePriority}, Version: ${updateInfo.availableVersionCode}');

        // Priority >= 4 indicates critical/mandatory update as configured in Play Console
        if (updateInfo.updatePriority >= 4 && updateInfo.immediateUpdateAllowed) {
          debugPrint('[PlayUpdateService] Launching native immediate update...');
          await InAppUpdate.performImmediateUpdate();
        } else if (updateInfo.flexibleUpdateAllowed) {
          debugPrint('[PlayUpdateService] Launching native flexible update...');
          final result = await InAppUpdate.startFlexibleUpdate();
          if (result == AppUpdateResult.success) {
            debugPrint('[PlayUpdateService] Flexible update downloaded, completing installation...');
            await InAppUpdate.completeFlexibleUpdate();
          }
        } else if (updateInfo.immediateUpdateAllowed) {
          debugPrint('[PlayUpdateService] Flexible not allowed, launching immediate update...');
          await InAppUpdate.performImmediateUpdate();
        }
      }
    } catch (e) {
      // Offline, Google Play services unavailable, emulator, or unowned app (sideload)
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
      final updateInfo = await InAppUpdate.checkForUpdate();

      if (updateInfo.updateAvailability == UpdateAvailability.developerTriggeredUpdateInProgress) {
        await InAppUpdate.performImmediateUpdate();
        return;
      }

      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        if (updateInfo.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
        } else if (updateInfo.flexibleUpdateAllowed) {
          final result = await InAppUpdate.startFlexibleUpdate();
          if (result == AppUpdateResult.success) {
            await InAppUpdate.completeFlexibleUpdate();
          }
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You are using the latest version of ClipVault.')),
          );
        }
      }
    } catch (e) {
      debugPrint('[PlayUpdateService] Manual check failed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to reach Google Play Store. Please check your connection.'),
          ),
        );
      }
    } finally {
      _isChecking = false;
    }
  }
}
