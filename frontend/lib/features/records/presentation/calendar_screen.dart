import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/async_content.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/record_card.dart';
import 'record_providers.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final monthDays = ref.watch(calendarDaysProvider(DateTime(_focusedDay.year, _focusedDay.month)));
    final selectedRecords = ref.watch(recordsByDateProvider(_selectedDay));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
      children: [
        Row(
          children: [
            IconButton(onPressed: () => context.go('/menu'), icon: const Icon(Icons.menu)),
            const SizedBox(width: 8),
            const Text('요리 캘린더', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.primaryContainer)),
          ],
        ),
        const SizedBox(height: 26),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: AppColors.surfaceLow, borderRadius: BorderRadius.circular(28)),
          child: AsyncContent(
            value: monthDays,
            onRetry: () => ref.invalidate(calendarDaysProvider(DateTime(_focusedDay.year, _focusedDay.month))),
            builder: (days) {
              final counts = {for (final day in days) DateUtils.dateOnly(day.date): day.count};
              return TableCalendar<int>(
                locale: 'ko',
                focusedDay: _focusedDay,
                firstDay: DateTime(2020),
                lastDay: DateTime.now(),
                selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
                onDaySelected: (selectedDay, focusedDay) {
                  if (selectedDay.isAfter(DateTime.now())) return;
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                onPageChanged: (focusedDay) => setState(() => _focusedDay = focusedDay),
                eventLoader: (day) => List.filled(counts[DateUtils.dateOnly(day)] ?? 0, 1),
                headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: false),
                calendarStyle: CalendarStyle(
                  selectedDecoration: const BoxDecoration(color: AppColors.primaryContainer, shape: BoxShape.circle),
                  todayDecoration: BoxDecoration(color: AppColors.primaryFixed, shape: BoxShape.circle),
                  markerDecoration: const BoxDecoration(color: AppColors.secondary, shape: BoxShape.circle),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('선택한 날짜', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700)),
                  Text(DateFormat('M월 d일 EEEE', 'ko').format(_selectedDay), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            FilledButton.tonal(
              onPressed: () => context.go('/records/new?date=${_dateParam(_selectedDay)}'),
              child: const Text('기록 작성'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        AsyncContent(
          value: selectedRecords,
          onRetry: () => ref.invalidate(recordsByDateProvider(_selectedDay)),
          builder: (records) {
            if (records.isEmpty) {
              return EmptyState(
                message: '이 날짜에는 기록이 없어요',
                actionLabel: '이 날짜로 기록 작성',
                onAction: () => context.go('/records/new?date=${_dateParam(_selectedDay)}'),
              );
            }
            return Column(
              children: [
                for (final record in records) ...[
                  RecordCard(
                    record: record,
                    compact: true,
                    onTap: () => context.go('/records/${record.id}'),
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  String _dateParam(DateTime date) => date.toIso8601String().split('T').first;
}
