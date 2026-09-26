import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/chat/presentation/chat_screen.dart';
import '../features/conversations/presentation/chats_list_screen.dart';
import '../features/inspector/presentation/activity_screen.dart';
import 'adaptive_shell.dart';
import 'theme/motion.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);
final GlobalKey<NavigatorState> chatsNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'chats',
);
final GlobalKey<NavigatorState> activityNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'activity');

Page<dynamic> _buildAdaptivePage(
  BuildContext context,
  GoRouterState state,
  Widget child,
) {
  final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  if (isMobile) {
    return MaterialPage<dynamic>(key: state.pageKey, child: child);
  }

  return CustomTransitionPage<dynamic>(
    key: state.pageKey,
    child: child,
    transitionDuration: MitraMotion.of(context, MitraMotion.slow),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: MitraMotion.emphasized,
        ),
        child: child,
      );
    },
  );
}

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/chats',
  routes: [
    GoRoute(path: '/', redirect: (context, state) => '/chats'),
    GoRoute(
      path: '/chat/:id',
      redirect: (_, state) => '/chats/${state.pathParameters['id']}',
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return AdaptiveShell(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          navigatorKey: chatsNavigatorKey,
          routes: [
            GoRoute(
              path: '/chats',
              pageBuilder: (context, state) =>
                  _buildAdaptivePage(context, state, const ChatsListScreen()),
              routes: [
                GoRoute(
                  path: ':id',
                  pageBuilder: (context, state) {
                    final id = state.pathParameters['id']!;
                    return _buildAdaptivePage(
                      context,
                      state,
                      ChatScreen(conversationId: id),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: activityNavigatorKey,
          routes: [
            GoRoute(
              path: '/activity',
              pageBuilder: (context, state) =>
                  _buildAdaptivePage(context, state, const ActivityScreen()),
            ),
          ],
        ),
      ],
    ),
  ],
);
