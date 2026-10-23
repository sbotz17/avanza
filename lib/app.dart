import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'providers/auth_provider.dart';
import 'services/firestore_service.dart';
import 'pages/login_page.dart';
import 'pages/client_home_page.dart';
import 'pages/home_page.dart';
import 'pages/project_page.dart';
import 'pages/task_detail_page.dart';
import 'pages/admin/edit_project_page.dart';
import 'pages/admin/edit_task_page.dart';
import 'pages/admin/costs_page.dart';
import 'pages/admin/team_page.dart';

class AvanzaApp extends StatefulWidget {
  const AvanzaApp({super.key});

  @override
  State<AvanzaApp> createState() => _AvanzaAppState();
}

class _AvanzaAppState extends State<AvanzaApp> {
  late final AuthProvider _auth = AuthProvider(
    roleResolver: (user) =>
        FirestoreService().resolveRole(user.uid, user.email ?? ''),
  );
  late final GoRouter _router = _buildRouter();

  @override
  void dispose() {
    _router.dispose();
    _auth.dispose();
    super.dispose();
  }

  // Solo percorsi interni: evita redirect verso indirizzi esterni.
  bool _isSafePath(String? p) => p != null && p.startsWith('/') && !p.startsWith('//');

  bool _isAdminOnly(String loc) =>
      loc == '/home' ||
      loc == '/team' ||
      loc.endsWith('/edit') ||
      loc.endsWith('/costs');

  String? _redirect(BuildContext context, GoRouterState state) {
    final loc = state.matchedLocation;
    final from = state.uri.queryParameters['from'];
    final here = Uri.encodeQueryComponent(state.uri.toString());

    // 1) La sessione viene ripristinata in modo asincrono (refresh, standby,
    //    riapertura): finché non è nota non si decide nulla e si ricorda dove
    //    voleva andare l'utente.
    if (_auth.isInitializing) {
      return loc == '/splash' ? null : '/splash?from=$here';
    }
    final home = _auth.isAdmin ? '/home' : '/client-home';
    if (loc == '/splash') {
      if (_isSafePath(from) && from != '/splash') return from;
      return _auth.isLoggedIn ? home : '/login';
    }

    // 2) Senza sessione: solo la pagina di accesso.
    if (!_auth.isLoggedIn) {
      if (loc == '/login') return null;
      return _isSafePath(state.uri.toString()) && loc != '/'
          ? '/login?from=$here'
          : '/login';
    }

    // 3) Con sessione: via dalla pagina di accesso e dalla radice.
    if (loc == '/login' || loc == '/') {
      return _isSafePath(from) ? from : home;
    }

    // 4) Ruoli: il cliente vede solo i suoi progetti e il dettaglio dei task.
    if (!_auth.isAdmin && _isAdminOnly(loc)) return '/client-home';
    if (_auth.isAdmin && loc == '/client-home') return '/home';
    return null;
  }

  GoRouter _buildRouter() => GoRouter(
        initialLocation: '/',
        refreshListenable: _auth,
        redirect: _redirect,
        routes: [
          GoRoute(path: '/', builder: (context, state) => const _Splash()),
          GoRoute(path: '/splash', builder: (context, state) => const _Splash()),
          GoRoute(
            path: '/login',
            builder: (context, state) => const LoginPage(),
          ),
          GoRoute(
            path: '/client-home',
            builder: (context, state) => const ClientHomePage(),
          ),
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomePage(),
          ),
          GoRoute(
            path: '/team',
            builder: (context, state) => const TeamPage(),
          ),
          GoRoute(
            path: '/project/:projectId',
            builder: (context, state) => ProjectPage(
              projectId: state.pathParameters['projectId']!,
            ),
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
            builder: (context, state) => TaskDetailPage(
              projectId: state.pathParameters['projectId']!,
              taskId: state.pathParameters['taskId']!,
            ),
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

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AuthProvider>.value(
      value: _auth,
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

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
