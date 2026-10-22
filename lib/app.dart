import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'providers/auth_provider.dart';
import 'pages/login_page.dart';
import 'pages/client_access_page.dart';
import 'pages/home_page.dart';
import 'pages/project_page.dart';
import 'pages/task_detail_page.dart';
import 'pages/admin/edit_project_page.dart';
import 'pages/admin/edit_task_page.dart';
import 'pages/admin/costs_page.dart';

final _router = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/client',
      builder: (context, state) => const ClientAccessPage(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      path: '/project/:projectId',
      builder: (context, state) {
        final projectId = state.pathParameters['projectId']!;
        final clientMode = state.uri.queryParameters['mode'] == 'client';
        return ProjectPage(projectId: projectId, clientMode: clientMode);
      },
    ),
    GoRoute(
      path: '/project/:projectId/edit',
      builder: (context, state) => EditProjectPage(
        projectId: state.pathParameters['projectId']!,
      ),
    ),
    GoRoute(
      path: '/project/:projectId/costs',
      builder: (context, state) => CostsPage(
        projectId: state.pathParameters['projectId']!,
      ),
    ),
    GoRoute(
      path: '/project/:projectId/task/:taskId',
      builder: (context, state) {
        final projectId = state.pathParameters['projectId']!;
        final taskId = state.pathParameters['taskId']!;
        final clientMode = state.uri.queryParameters['mode'] == 'client';
        return TaskDetailPage(
          projectId: projectId,
          taskId: taskId,
          clientMode: clientMode,
        );
      },
    ),
    GoRoute(
      path: '/project/:projectId/task/:taskId/edit',
      builder: (context, state) {
        final projectId = state.pathParameters['projectId']!;
        final taskId = state.pathParameters['taskId']!;
        return EditTaskPage(
          projectId: projectId,
          taskId: taskId == 'new' ? null : taskId,
        );
      },
    ),
  ],
);

class AvanzaApp extends StatelessWidget {
  const AvanzaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp.router(
        title: 'Avanza',
        debugShowCheckedModeBanner: false,
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: ThemeMode.system,
        routerConfig: _router,
      ),
    );
  }
}
