import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AsyncContent<T> extends StatelessWidget {
  const AsyncContent({
    super.key,
    required this.value,
    required this.builder,
    this.empty,
    this.onRetry,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final Widget? empty;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: builder,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, size: 42),
              const SizedBox(height: 12),
              Text(_friendlyError(error), textAlign: TextAlign.center),
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('다시 시도'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _friendlyError(Object error) {
    final message = error.toString();
    if (message.contains('XMLHttpRequest') ||
        message.contains('Connection refused') ||
        message.contains('SocketException') ||
        message.contains('Failed host lookup')) {
      return '백엔드 API에 연결할 수 없어요.\n백엔드를 실행한 뒤 다시 시도해주세요.';
    }
    if (message.length > 160) {
      return '데이터를 불러오지 못했어요.\n잠시 후 다시 시도해주세요.';
    }
    return '데이터를 불러오지 못했어요.\n$message';
  }
}
