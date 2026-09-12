import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import '../storage/preferences_service.dart';
import '../utils/url_validator.dart';
import 'content_authorization.dart';

/// Minimal, privacy-compliant audit log entry.
///
/// Under strict privacy requirements, audit records NEVER store:
/// - Passwords or credentials
/// - Session cookies or tokens
/// - Private user profile data
/// - Full raw URLs that may contain sensitive query tokens
class ComplianceAuditRecord {
  final String id;
  final String platform;
  final String action; // 'inspect', 'download', 'policy_accept', 'complaint'
  final String decision; // 'permitted', 'denied'
  final String authorizationType;
  final String buildMode; // 'play_store', 'standard'
  final String policyVersion;
  final DateTime timestamp;
  final String? reason;

  const ComplianceAuditRecord({
    required this.id,
    required this.platform,
    required this.action,
    required this.decision,
    required this.authorizationType,
    required this.buildMode,
    required this.policyVersion,
    required this.timestamp,
    this.reason,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'platform': platform,
        'action': action,
        'decision': decision,
        'authorizationType': authorizationType,
        'buildMode': buildMode,
        'policyVersion': policyVersion,
        'timestamp': timestamp.toIso8601String(),
        if (reason != null) 'reason': reason,
      };

  factory ComplianceAuditRecord.fromJson(Map<String, dynamic> json) {
    return ComplianceAuditRecord(
      id: json['id'] as String? ?? '',
      platform: json['platform'] as String? ?? 'unknown',
      action: json['action'] as String? ?? 'unknown',
      decision: json['decision'] as String? ?? 'unknown',
      authorizationType: json['authorizationType'] as String? ?? 'unknown',
      buildMode: json['buildMode'] as String? ?? 'unknown',
      policyVersion: json['policyVersion'] as String? ?? AppConfig.policyVersion,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      reason: json['reason'] as String?,
    );
  }
}

/// Service managing non-sensitive compliance audit logs.
class ComplianceAuditService {
  final PreferencesService _prefs;

  ComplianceAuditService(this._prefs);

  static const _keyAuditLogs = 'compliance_audit_logs';
  static const int _maxAuditEntries = 50;

  /// Record an audit event.
  Future<void> recordEvent({
    required MediaPlatform platform,
    required String action,
    required String decision,
    ContentAuthorizationType? authorizationType,
    String? reason,
  }) async {
    final entry = ComplianceAuditRecord(
      id: 'audit_${DateTime.now().millisecondsSinceEpoch}',
      platform: platform.name,
      action: action,
      decision: decision,
      authorizationType: authorizationType?.name ?? 'unspecified',
      buildMode: AppConfig.isPlayStoreBuild ? 'play_store' : 'standard',
      policyVersion: AppConfig.policyVersion,
      timestamp: DateTime.now(),
      reason: reason,
    );

    await _persistAuditRecord(entry);
  }

  /// Get the list of recorded non-sensitive compliance events.
  List<ComplianceAuditRecord> getRecentAuditLogs() {
    final rawJsonList = _prefs.getStringList(_keyAuditLogs);
    if (rawJsonList == null || rawJsonList.isEmpty) return [];

    return rawJsonList.map((raw) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        return ComplianceAuditRecord.fromJson(map);
      } catch (_) {
        return null;
      }
    }).whereType<ComplianceAuditRecord>().toList();
  }

  Future<void> _persistAuditRecord(ComplianceAuditRecord record) async {
    final existing = _prefs.getStringList(_keyAuditLogs) ?? [];
    final updated = List<String>.from(existing);

    // Add new event at the beginning
    updated.insert(0, jsonEncode(record.toJson()));

    // Keep only the most recent entries (rolling buffer)
    if (updated.length > _maxAuditEntries) {
      updated.removeRange(_maxAuditEntries, updated.length);
    }

    await _prefs.setStringList(_keyAuditLogs, updated);
  }

  /// Clear audit logs (e.g. on user data reset request).
  Future<void> clearLogs() async {
    await _prefs.removeKey(_keyAuditLogs);
  }
}

final complianceAuditServiceProvider = Provider<ComplianceAuditService>((ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  return ComplianceAuditService(prefs);
});
