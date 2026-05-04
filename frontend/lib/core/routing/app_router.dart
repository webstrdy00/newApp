import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_providers.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/menu/presentation/menu_screen.dart';
import '../../features/records/presentation/calendar_screen.dart';
import '../../features/records/presentation/clone_record_screen.dart';
import '../../features/records/presentation/home_screen.dart';
import '../../features/records/presentation/record_detail_screen.dart';
import '../../features/records/presentation/record_form_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../shared/widgets/app_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);
  return GoRouter(
    initialLocation: '/home',
    redirect: (context, state) {
      final location = state.uri.path;
      final isAuthRoute = location == '/login' || location == '/register';
      if (authState.isLoading) return null;
      if (!authState.isAuthenticated && !isAuthRoute) return '/login';
      if (authState.isAuthenticated && isAuthRoute) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
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
