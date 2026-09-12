import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import '../errors/app_exceptions.dart';
import '../utils/url_validator.dart';
import 'content_authorization.dart';
import 'source_policy.dart';

/// Exception thrown when a media inspection or download action violates
/// platform policies, terms of service, or legal compliance requirements.
class PolicyViolationException extends AppException {
  final SourcePolicy? policy;

  const PolicyViolationException(super.message, {this.policy});

  @override
  String toString() => message;
}

/// Result of a policy verification check.
class PolicyDecision {
  final bool isAllowed;
  final String? denialReason;
  final SourcePolicy policy;

  const PolicyDecision({
    required this.isAllowed,
    this.denialReason,
    required this.policy,
  });

  factory PolicyDecision.allowed(SourcePolicy policy) {
    return PolicyDecision(
      isAllowed: true,
      policy: policy,
    );
  }

  factory PolicyDecision.denied(SourcePolicy policy, String reason) {
    return PolicyDecision(
      isAllowed: false,
      denialReason: reason,
      policy: policy,
    );
  }
}

/// Central technical compliance and safety policy engine.
///
/// Ensures all media inspection, processing, and download operations strictly
/// follow source-specific policies, Google Play Store rules, and user authorization checks.
class CompliancePolicyEngine {
  final bool isPlayStoreBuild;

  const CompliancePolicyEngine({
    this.isPlayStoreBuild = AppConfig.isPlayStoreBuild,
  });

  /// Verify whether inspecting the given platform source is permitted under active policies.
  ///
  /// Throws [PolicyViolationException] if the action is prohibited.
  PolicyDecision verifyInspectionPermission(MediaPlatform platform, String rawUrl) {
    final policy = SourcePolicy.getPolicy(
      platform,
      isPlayStoreBuild: isPlayStoreBuild,
    );

    // 1. Check if platform is completely disabled or unsupported
    if (policy.status == SourcePolicyStatus.disabled ||
        platform == MediaPlatform.unsupported) {
      throw PolicyViolationException(
        SourcePolicy.failSafeNotice,
        policy: policy,
      );
    }

    // 2. Check if platform is disabled in Google Play Store builds
    if (isPlayStoreBuild && !policy.isPermittedInPlayStore) {
      throw PolicyViolationException(
        policy.policyNotice,
        policy: policy,
      );
    }

    return PolicyDecision.allowed(policy);
  }

  /// Verify whether a download operation is legally and technically authorized to proceed.
  ///
  /// Requires:
  /// - The user has accepted the Master Copyright & Policy Agreement.
  /// - The user has declared an authorization basis for this specific media.
  /// - The source is allowed under the current build distribution.
  PolicyDecision verifyDownloadPermission({
    required MediaPlatform platform,
    required ContentAuthorizationType authorizationType,
    required bool hasAcceptedPolicy,
  }) {
    final policy = SourcePolicy.getPolicy(
      platform,
      isPlayStoreBuild: isPlayStoreBuild,
    );

    // 1. Mandatory policy acceptance verification
    if (!hasAcceptedPolicy) {
      throw PolicyViolationException(
        'You must read and accept the Copyright & Acceptable Use Policy before downloading any media.',
        policy: policy,
      );
    }

    // 2. Google Play Build restriction verification
    if (isPlayStoreBuild && !policy.isPermittedInPlayStore) {
      throw PolicyViolationException(
        policy.policyNotice,
        policy: policy,
      );
    }

    // 3. Platform disabled verification
    if (policy.status == SourcePolicyStatus.disabled ||
        platform == MediaPlatform.unsupported) {
      throw PolicyViolationException(
        SourcePolicy.failSafeNotice,
        policy: policy,
      );
    }

    return PolicyDecision.allowed(policy);
  }
}

/// Global provider for the compliance policy engine.
final compliancePolicyEngineProvider = Provider<CompliancePolicyEngine>((ref) {
  return const CompliancePolicyEngine();
});
