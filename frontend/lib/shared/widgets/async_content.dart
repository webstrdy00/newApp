import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AsyncContent<T> extends StatelessWidget {
  const AsyncContent({
    super.key,
    required this.value,
    required this.builder,
    this.empty,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final Widget? empty;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: builder,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('데이터를 불러오지 못했어요\n$error', textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
