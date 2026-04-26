import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/record_models.dart';
import '../data/records_repository.dart';

final todayRecordsProvider = FutureProvider.autoDispose<List<CookingRecord>>((ref) {
  return ref.watch(recordsRepositoryProvider).today();
});

final recentRecordsProvider = FutureProvider.autoDispose<List<CookingRecord>>((ref) {
  return ref.watch(recordsRepositoryProvider).recent();
});

final recordProvider = FutureProvider.autoDispose.family<CookingRecord, int>((ref, id) {
  return ref.watch(recordsRepositoryProvider).read(id);
});

final recordsByDateProvider = FutureProvider.autoDispose.family<List<CookingRecord>, DateTime>((ref, date) {
  return ref.watch(recordsRepositoryProvider).byDate(date);
});

final calendarDaysProvider = FutureProvider.autoDispose.family<List<CalendarRecordDay>, DateTime>((ref, month) {
  return ref.watch(recordsRepositoryProvider).calendarDays(month);
});

final searchResultsProvider = FutureProvider.autoDispose.family<List<CookingRecord>, SearchQuery>((ref, query) {
  if (query.text.trim().isEmpty) {
    return const [];
  }
  return ref.watch(recordsRepositoryProvider).search(query: query.text, filter: query.filter);
});

class SearchQuery {
  const SearchQuery({required this.text, required this.filter});

  final String text;
  final String filter;

  @override
  bool operator ==(Object other) {
    return other is SearchQuery && other.text == text && other.filter == filter;
  }

  @override
  int get hashCode => Object.hash(text, filter);
}
