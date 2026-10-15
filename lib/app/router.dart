import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/assistant/ai_chat_screen.dart';
import '../features/attendance/attendance_screen.dart';
import '../features/auth/founder_otp_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/password_change_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/documents/documents_screen.dart';
import '../features/feed/feed_screen.dart';
import '../features/home/home_screen.dart';
import '../features/home/main_shell.dart';
import '../features/leave/leave_screen.dart';
import '../features/messages/messages_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/payments/payments_screen.dart';
import '../features/people/people_search_screen.dart';
import '../features/profile/coworker_profile_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/projects/projects_screen.dart';
import '../features/assignments/assignments_screen.dart';
import '../features/classes/daily_topics_screen.dart';
import '../features/search/global_search_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/store/codexa_store_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'shell',
);

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/splash',
  routes: [
    // Entry / Auth Routes
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/founder-otp',
      builder: (context, state) => const FounderOtpScreen(),
    ),
    GoRoute(
      path: '/password-change',
      builder: (context, state) => const PasswordChangeScreen(),
    ),

    // Main 5-Tab Shell Navigation
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(
          path: '/home',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: HomeScreen()),
        ),
        GoRoute(
          path: '/attendance',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: AttendanceScreen()),
        ),
        GoRoute(
          path: '/messages',
          pageBuilder: (context, state) => NoTransitionPage(
            child: MessagesScreen(
              initialConversationId:
                  state.uri.queryParameters['conversationId'],
            ),
          ),
        ),
        GoRoute(
          path: '/feed',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: FeedScreen()),
        ),
        GoRoute(
          path: '/projects',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ProjectsScreen()),
        ),
      ],
    ),

    // Chat Conversation Route
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/chat/:id',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        final name = state.uri.queryParameters['name'] ?? 'Direct Message';
        final messageId = state.uri.queryParameters['messageId'];
        return ChatConversationScreen(
          initialMessageId: messageId,
          conversation: {'id': id, 'name': name, 'title': name},
        );
      },
    ),

    // Search & Directory Routes
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/search',
      builder: (context, state) => const GlobalSearchScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/global-search',
      builder: (context, state) => const GlobalSearchScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/people',
      builder: (context, state) => const PeopleSearchScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/profile/:username',
      builder: (context, state) {
        final username = state.pathParameters['username'] ?? '';
        return CoworkerProfileScreen(username: username);
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/coworker-profile/:username',
      builder: (context, state) {
        final username = state.pathParameters['username'] ?? '';
        return CoworkerProfileScreen(username: username);
      },
    ),

    // AI Workplace Assistant Route
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/ai',
      builder: (context, state) => const CodexaAiScreen(),
    ),

    // Push Detail Routes
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/notifications',
      builder: (context, state) => const NotificationsScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/leave',
      builder: (context, state) => const LeaveScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/payments',
      builder: (context, state) => PaymentsScreen(
        initialPaymentId:
            state.uri.queryParameters['review'] ??
            state.uri.queryParameters['paymentId'],
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/documents',
      builder: (context, state) => const DocumentsScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/topics',
      builder: (context, state) => const DailyTopicsScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/assignments',
      builder: (context, state) => const AssignmentsScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/store',
      builder: (context, state) => const CodeXaStoreScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/codexa-store',
      builder: (context, state) => const CodeXaStoreScreen(),
    ),
  ],
);
