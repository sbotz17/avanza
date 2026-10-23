import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../services/firestore_service.dart';
import '../../models/project.dart';
import '../../models/task.dart';
import '../../core/constants.dart';
import 'time_report.dart';

class CostsPage extends StatelessWidget {
  final String projectId;

  const CostsPage({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final eur = NumberFormat.currency(locale: 'it_IT', symbol: '€');
    final fg2 = isDark ? kFg2Dark : kFg2Light;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/project/$projectId'),
        ),
        title: const Text('Costi sviluppo'),
      ),
      body: FutureBuilder<Project?>(
        future: service.getProject(projectId),
        builder: (context, projSnap) {
          final project = projSnap.data;

          return StreamBuilder<List<Task>>(
            stream: service.tasksStream(projectId),
            builder: (context, snap) {
              final tasks = snap.data ?? [];

              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final totalEstCost = tasks.fold<double>(
                0,
                (s, t) => s + t.estimatedCost,
              );
              final totalActCost = tasks.fold<double>(
                0,
                (s, t) => s + t.actualCost,
              );
              final totalEstH = tasks.fold<double>(
                0,
                (s, t) => s + t.estimatedHours,
              );
              final totalActH = tasks.fold<double>(
                0,
                (s, t) => s + t.actualHours,
              );

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Project summary header
                    if (project != null) ...[
                      Text(
                        project.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Codice cliente: ${project.clientCode}',
                        style: TextStyle(fontSize: 13, color: fg2),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Summary cards
                    Row(
                      children: [
                        _SummaryCard(
                          label: 'Ore stimate',
                          value: '${totalEstH.toStringAsFixed(1)}h',
                          color: isDark ? kActiveColorDark : kActiveColor,
                          isDark: isDark,
                        ),
                        const SizedBox(width: 10),
                        _SummaryCard(
                          label: 'Ore reali',
                          value: '${totalActH.toStringAsFixed(1)}h',
                          color: totalActH > totalEstH
                              ? (isDark ? kBlockedColorDark : kBlockedColor)
                              : (isDark ? kDoneColorDark : kDoneColor),
                          isDark: isDark,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _SummaryCard(
                          label: 'Costo stimato',
                          value: eur.format(totalEstCost),
                          color: isDark ? kActiveColorDark : kActiveColor,
                          isDark: isDark,
                        ),
                        const SizedBox(width: 10),
                        _SummaryCard(
                          label: 'Costo reale',
                          value: eur.format(totalActCost),
                          color: totalActCost > totalEstCost
                              ? (isDark ? kBlockedColorDark : kBlockedColor)
                              : (isDark ? kDoneColorDark : kDoneColor),
                          isDark: isDark,
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Task table
                    Text(
                      'DETTAGLIO PER TASK',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: fg2,
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (tasks.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'Nessun task nel progetto.',
                          style: TextStyle(color: fg2, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ...tasks.map(
                        (task) => _TaskCostCard(
                          task: task,
                          isDark: isDark,
                          eur: eur,
                          fg2: fg2,
                        ),
                      ),

                    TimeReportSection(projectId: projectId, tasks: tasks),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? kCardDark : kCardLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? kBorderDark : kBorderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? kFg2Dark : kFg2Light,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskCostCard extends StatelessWidget {
  final Task task;
  final bool isDark;
  final NumberFormat eur;
  final Color fg2;

  const _TaskCostCard({
    required this.task,
    required this.isDark,
    required this.eur,
    required this.fg2,
  });

  @override
  Widget build(BuildContext context) {
    final overBudget = task.actualHours > task.estimatedHours &&
        task.estimatedHours > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? kCardDark : kCardLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: overBudget
              ? (isDark ? kBlockedColorDark : kBlockedColor)
                  .withValues(alpha: 0.5)
              : (isDark ? kBorderDark : kBorderLight),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _CostCell(
                label: 'Ore stimate',
                value: '${task.estimatedHours.toStringAsFixed(1)}h',
                fg2: fg2,
              ),
              _CostCell(
                label: 'Ore reali',
                value: '${task.actualHours.toStringAsFixed(1)}h',
                valueColor: overBudget
                    ? (isDark ? kBlockedColorDark : kBlockedColor)
                    : null,
                fg2: fg2,
              ),
              _CostCell(
                label: 'Tariffa',
                value: '${eur.format(task.hourlyRate)}/h',
                fg2: fg2,
              ),
              _CostCell(
                label: 'Costo stim.',
                value: eur.format(task.estimatedCost),
                fg2: fg2,
              ),
              _CostCell(
                label: 'Costo reale',
                value: eur.format(task.actualCost),
                valueColor: overBudget
                    ? (isDark ? kBlockedColorDark : kBlockedColor)
                    : (isDark ? kDoneColorDark : kDoneColor),
                fg2: fg2,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CostCell extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final Color fg2;

  const _CostCell({
    required this.label,
    required this.value,
    required this.fg2,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 9, color: fg2)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
