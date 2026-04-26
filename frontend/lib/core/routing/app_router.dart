import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/menu/presentation/menu_screen.dart';
import '../../features/records/presentation/calendar_screen.dart';
import '../../features/records/presentation/clone_record_screen.dart';
import '../../features/records/presentation/home_screen.dart';
import '../../features/records/presentation/record_detail_screen.dart';
import '../../features/records/presentation/record_form_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../shared/widgets/app_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
          GoRoute(path: '/calendar', builder: (context, state) => const CalendarScreen()),
          GoRoute(path: '/search', builder: (context, state) => const SearchScreen()),
          GoRoute(path: '/menu', builder: (context, state) => const MenuScreen()),
          GoRoute(
            path: '/records/new',
            builder: (context, state) => RecordFormScreen(
              initialDate: DateTime.tryParse(state.uri.queryParameters['date'] ?? ''),
              cloneFromRecordId: int.tryParse(state.uri.queryParameters['cloneFrom'] ?? ''),
            ),
          ),
          GoRoute(
            path: '/records/:id',
            builder: (context, state) => RecordDetailScreen(
              recordId: int.parse(state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/records/:id/edit',
            builder: (context, state) => RecordFormScreen(
              recordId: int.parse(state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/records/:id/clone',
            builder: (context, state) => CloneRecordScreen(
              recordId: int.parse(state.pathParameters['id']!),
            ),
          ),
        ],
      ),
    ],
  );
});
