import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import '../models/project.dart';
import '../core/constants.dart';
import '../widgets/empty_state.dart';
import 'admin/edit_project_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!auth.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/login'));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final service = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('I miei progetti'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            onPressed: () async {
              await auth.signOut();
              if (context.mounted) context.go('/login');
            },
            tooltip: 'Esci',
          ),
        ],
      ),
      body: StreamBuilder<List<Project>>(
        stream: service.projectsStream(auth.user!.uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.error_outline,
              title: 'Errore nel caricamento',
              subtitle: snap.error.toString(),
            );
          }
          final projects = snap.data ?? [];
          if (projects.isEmpty) {
            return EmptyState(
              icon: Icons.folder_outlined,
              title: 'Nessun progetto',
              subtitle: 'Crea il primo progetto per iniziare.',
              action: FilledButton.icon(
                onPressed: () => _addProject(context, auth.user!.uid, service),
                icon: const Icon(Icons.add),
                label: const Text('Nuovo progetto'),
                style: FilledButton.styleFrom(
                  backgroundColor: isDark ? kActiveColorDark : kActiveColor,
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: projects.length,
            itemBuilder: (context, i) =>
                _ProjectCard(project: projects[i], service: service),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addProject(context, auth.user!.uid, service),
        icon: const Icon(Icons.add),
        label: const Text('Nuovo progetto'),
      ),
    );
  }

  void _addProject(
      BuildContext context, String ownerId, FirestoreService service) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditProjectSheet(
        ownerId: ownerId,
        service: service,
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final Project project;
  final FirestoreService service;

  const _ProjectCard({required this.project, required this.service});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? kCardDark : kCardLight;
    final borderColor = isDark ? kBorderDark : kBorderLight;
    final fg2 = isDark ? kFg2Dark : kFg2Light;

    return GestureDetector(
      onTap: () => context.go('/project/${project.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    project.name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                Icon(Icons.chevron_right, color: fg2, size: 20),
              ],
            ),
            if (project.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                project.description,
                style: TextStyle(fontSize: 13, color: fg2),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                // Client code chip
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? kActiveBgDark : kActiveBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.link,
                          size: 12,
                          color: isDark ? kActiveColorDark : kActiveColor),
                      const SizedBox(width: 4),
                      Text(
                        project.clientCode,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? kActiveColorDark : kActiveColor,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                if (project.githubUrl.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.code_rounded, size: 14, color: fg2),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      _shortGithubUrl(project.githubUrl),
                      style: TextStyle(fontSize: 11, color: fg2),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _shortGithubUrl(String url) {
    return url
        .replaceFirst('https://github.com/', '')
        .replaceFirst('http://github.com/', '');
  }
}
