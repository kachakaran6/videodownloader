/// Declaration of the user's legal right or authorization to access and download media.
///
/// Under applicable copyright laws and platform policies, users may only download
/// or process media when they possess an authentic lawful basis to do so.
enum ContentAuthorizationType {
  /// The user is the original creator and copyright owner of the content.
  owner,

  /// The user has obtained express written or contractual permission/license
  /// from the copyright owner.
  licensee,

  /// The content is in the public domain and free of active copyright restrictions.
  publicDomain,

  /// The content is distributed under a permissive license (such as Creative Commons)
  /// that explicitly grants download and offline usage rights.
  creativeCommons,

  /// The user has an independent lawful right, statutory exemption, or authorized use case.
  lawfulUse;

  /// User-facing short label.
  String get label {
    switch (this) {
      case ContentAuthorizationType.owner:
        return 'I own this content';
      case ContentAuthorizationType.licensee:
        return 'I have permission / license';
      case ContentAuthorizationType.publicDomain:
        return 'Public domain';
      case ContentAuthorizationType.creativeCommons:
        return 'Creative Commons / permitted license';
      case ContentAuthorizationType.lawfulUse:
        return 'Other lawful authorization';
    }
  }

  /// User-facing detailed legal description.
  String get description {
    switch (this) {
      case ContentAuthorizationType.owner:
        return 'You are the original creator and retain full ownership rights.';
      case ContentAuthorizationType.licensee:
        return 'You have explicit permission or an active license from the rights holder.';
      case ContentAuthorizationType.publicDomain:
        return 'The work is in the public domain and not subject to copyright protection.';
      case ContentAuthorizationType.creativeCommons:
        return 'The work is released under a CC or open license authorizing downloading.';
      case ContentAuthorizationType.lawfulUse:
        return 'You have an applicable statutory right or lawful authorization to save this media.';
    }
  }

  /// String identifier for serialization and audit logging.
  String get id => name;

  /// Parse from string identifier.
  static ContentAuthorizationType fromId(String? id) {
    if (id == null) return ContentAuthorizationType.owner;
    return ContentAuthorizationType.values.firstWhere(
      (e) => e.name == id,
      orElse: () => ContentAuthorizationType.owner,
    );
  }
}
