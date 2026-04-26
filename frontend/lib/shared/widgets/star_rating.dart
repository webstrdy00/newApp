import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class StarRating extends StatelessWidget {
  const StarRating({
    super.key,
    required this.value,
    this.onChanged,
    this.size = 28,
  });

  final int? value;
  final ValueChanged<int>? onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final star = index + 1;
        final selected = (value ?? 0) >= star;
        return IconButton(
          tooltip: '$star점',
          visualDensity: VisualDensity.compact,
          onPressed: onChanged == null ? null : () => onChanged!(star),
          icon: Icon(
            selected ? Icons.star : Icons.star_border,
            color: selected ? AppColors.primaryContainer : AppColors.outline,
            size: size,
          ),
        );
      }),
    );
  }
}
