import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/compliance/copyright_complaint_repository.dart';
import '../../../core/theme/app_colors.dart';

/// In-app form enabling copyright owners and rights holders to report content issues
/// or submit takedown requests.
class CopyrightComplaintDialog extends ConsumerStatefulWidget {
  final String? initialUrl;

  const CopyrightComplaintDialog({super.key, this.initialUrl});

  static Future<void> show(BuildContext context, {String? initialUrl}) {
    return showDialog(
      context: context,
      builder: (context) => CopyrightComplaintDialog(initialUrl: initialUrl),
    );
  }

  @override
  ConsumerState<CopyrightComplaintDialog> createState() => _CopyrightComplaintDialogState();
}

class _CopyrightComplaintDialogState extends ConsumerState<CopyrightComplaintDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _urlController;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _ownershipController = TextEditingController();
  String _requestedAction = 'takedown';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl ?? '');
  }

  @override
  void dispose() {
    _urlController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _descController.dispose();
    _ownershipController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      await ref.read(copyrightComplaintRepositoryProvider).submitComplaint(
            contentUrl: _urlController.text,
            rightsHolderName: _nameController.text,
            contactEmail: _emailController.text,
            description: _descController.text,
            ownershipDetails: _ownershipController.text,
            requestedAction: _requestedAction,
          );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF01875F),
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Complaint submitted. Our legal team will review your report.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Failed to submit: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.report_problem_rounded, color: AppColors.error, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Report Copyright Issue',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                Text(
                  'Rights Holder Content Complaint',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'If you are a copyright owner or authorized representative and believe content '
                'is being accessed in violation of your rights, submit this notice.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary(context),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),

              // Content URL
              TextFormField(
                controller: _urlController,
                style: TextStyle(fontSize: 13, color: AppColors.textPrimary(context)),
                decoration: InputDecoration(
                  labelText: 'Content URL *',
                  hintText: 'https://...',
                  filled: true,
                  fillColor: AppColors.surface(context),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'URL is required' : null,
              ),
              const SizedBox(height: 12),

              // Rights Holder Name
              TextFormField(
                controller: _nameController,
                style: TextStyle(fontSize: 13, color: AppColors.textPrimary(context)),
                decoration: InputDecoration(
                  labelText: 'Rights Holder / Owner Name *',
                  filled: true,
                  fillColor: AppColors.surface(context),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),

              // Contact Email
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(fontSize: 13, color: AppColors.textPrimary(context)),
                decoration: InputDecoration(
                  labelText: 'Contact Email Address *',
                  filled: true,
                  fillColor: AppColors.surface(context),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => (v == null || !v.contains('@')) ? 'Valid email required' : null,
              ),
              const SizedBox(height: 12),

              // Ownership Information
              TextFormField(
                controller: _ownershipController,
                style: TextStyle(fontSize: 13, color: AppColors.textPrimary(context)),
                decoration: InputDecoration(
                  labelText: 'Copyright Ownership Proof / Basis *',
                  hintText: 'e.g. Creator, trademark owner, licensing agency',
                  filled: true,
                  fillColor: AppColors.surface(context),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              // Description
              TextFormField(
                controller: _descController,
                maxLines: 2,
                style: TextStyle(fontSize: 13, color: AppColors.textPrimary(context)),
                decoration: InputDecoration(
                  labelText: 'Description of Infringement *',
                  filled: true,
                  fillColor: AppColors.surface(context),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Description required' : null,
              ),
              const SizedBox(height: 12),

              // Requested Action
              DropdownButtonFormField<String>(
                initialValue: _requestedAction,
                dropdownColor: AppColors.surfaceElevated(context),
                style: TextStyle(fontSize: 13, color: AppColors.textPrimary(context)),
                decoration: InputDecoration(
                  labelText: 'Requested Action',
                  filled: true,
                  fillColor: AppColors.surface(context),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(value: 'takedown', child: Text('Block Source & Restrict Access')),
                  DropdownMenuItem(value: 'inquiry', child: Text('Copyright Inquiry / Verification')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _requestedAction = val);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: AppColors.textMuted(context))),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Submit Complaint', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
