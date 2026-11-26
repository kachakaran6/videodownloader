import 'package:flutter/material.dart';
import 'ad_slot.dart';

/// Clean wrapper around [AdSlot] maintaining backward compatibility
/// across Home, Library, and Status screens.
class NativeAdCard extends StatelessWidget {
  final VoidCallback? onRemoveAdsTap;
  final double height;

  const NativeAdCard({
    super.key,
    this.onRemoveAdsTap,
    this.height = 340.0,
  });

  @override
  Widget build(BuildContext context) {
    return AdSlot(
      onRemoveAdsTapped: onRemoveAdsTap,
      height: height,
    );
  }
}
