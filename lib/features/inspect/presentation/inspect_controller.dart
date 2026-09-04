import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/video_inspector.dart';
import '../../../core/errors/app_exceptions.dart';

final videoInspectorProvider = Provider<VideoInspector>((ref) {
  final inspector = VideoInspector();
  ref.onDispose(inspector.close);
  return inspector;
});

class InspectState {
  final bool isLoading;
  final VideoInspectionResult? result;
  final String? errorMessage;

  const InspectState({
    this.isLoading = false,
    this.result,
    this.errorMessage,
  });

  InspectState copyWith({
    bool? isLoading,
    VideoInspectionResult? result,
    String? errorMessage,
    bool clearError = false,
  }) {
    return InspectState(
      isLoading: isLoading ?? this.isLoading,
      result: result ?? this.result,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class InspectController extends Notifier<InspectState> {
  @override
  InspectState build() => const InspectState();

  Future<VideoInspectionResult?> checkUrl(String rawUrl) async {
    final inspector = ref.read(videoInspectorProvider);
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await inspector.inspect(rawUrl);
      state = state.copyWith(isLoading: false, result: result);
      return result;
    } on AppException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return null;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'An unexpected error occurred while inspecting the video.',
      );
      return null;
    }
  }

  void reset() {
    state = const InspectState();
  }
}

final inspectControllerProvider =
    NotifierProvider<InspectController, InspectState>(InspectController.new);
