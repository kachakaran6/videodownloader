import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/preferences_service.dart';

/// Representation of a rights holder's copyright takedown or content complaint.
class CopyrightComplaint {
  final String id;
  final String contentUrl;
  final String rightsHolderName;
  final String contactEmail;
  final String description;
  final String ownershipDetails;
  final String requestedAction; // 'takedown', 'block', 'inquiry'
  final DateTime submittedAt;
  final String status; // 'submitted', 'in_review', 'resolved'

  const CopyrightComplaint({
    required this.id,
    required this.contentUrl,
    required this.rightsHolderName,
    required this.contactEmail,
    required this.description,
    required this.ownershipDetails,
    required this.requestedAction,
    required this.submittedAt,
    this.status = 'submitted',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'contentUrl': contentUrl,
        'rightsHolderName': rightsHolderName,
        'contactEmail': contactEmail,
        'description': description,
        'ownershipDetails': ownershipDetails,
        'requestedAction': requestedAction,
        'submittedAt': submittedAt.toIso8601String(),
        'status': status,
      };

  factory CopyrightComplaint.fromJson(Map<String, dynamic> json) {
    return CopyrightComplaint(
      id: json['id'] as String? ?? '',
      contentUrl: json['contentUrl'] as String? ?? '',
      rightsHolderName: json['rightsHolderName'] as String? ?? '',
      contactEmail: json['contactEmail'] as String? ?? '',
      description: json['description'] as String? ?? '',
      ownershipDetails: json['ownershipDetails'] as String? ?? '',
      requestedAction: json['requestedAction'] as String? ?? 'takedown',
      submittedAt: DateTime.tryParse(json['submittedAt'] as String? ?? '') ?? DateTime.now(),
      status: json['status'] as String? ?? 'submitted',
    );
  }
}

/// Repository for handling and storing copyright complaints submitted in-app.
class CopyrightComplaintRepository {
  final PreferencesService _prefs;

  CopyrightComplaintRepository(this._prefs);

  static const _keyComplaints = 'copyright_complaints_log';

  /// Submit a new copyright / content issue.
  Future<CopyrightComplaint> submitComplaint({
    required String contentUrl,
    required String rightsHolderName,
    required String contactEmail,
    required String description,
    required String ownershipDetails,
    required String requestedAction,
  }) async {
    final complaint = CopyrightComplaint(
      id: 'complaint_${DateTime.now().millisecondsSinceEpoch}',
      contentUrl: contentUrl.trim(),
      rightsHolderName: rightsHolderName.trim(),
      contactEmail: contactEmail.trim(),
      description: description.trim(),
      ownershipDetails: ownershipDetails.trim(),
      requestedAction: requestedAction,
      submittedAt: DateTime.now(),
      status: 'submitted',
    );

    final existing = _prefs.getStringList(_keyComplaints) ?? [];
    final updated = List<String>.from(existing)..insert(0, jsonEncode(complaint.toJson()));
    await _prefs.setStringList(_keyComplaints, updated);

    return complaint;
  }

  /// Retrieve all submitted complaints for review.
  List<CopyrightComplaint> getComplaints() {
    final list = _prefs.getStringList(_keyComplaints) ?? [];
    return list.map((raw) {
      try {
        return CopyrightComplaint.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }).whereType<CopyrightComplaint>().toList();
  }
}

final copyrightComplaintRepositoryProvider = Provider<CopyrightComplaintRepository>((ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  return CopyrightComplaintRepository(prefs);
});
