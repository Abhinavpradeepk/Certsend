import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/certificate_project.dart';
import '../providers/project_provider.dart';
import '../theme/app_theme.dart';
import 'create_project_screen.dart';
import 'history_screen.dart';
import 'project_detail_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final projects = context.watch<ProjectProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('CertiSend', style: TextStyle(fontWeight: FontWeight.w800)), actions: [IconButton(tooltip: 'Settings', onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())), icon: const Icon(Icons.tune_rounded)), const SizedBox(width: 8)]),
      body: projects.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: projects.load,
              child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
                const Text('Certificates,\nwithout the busywork.', style: TextStyle(color: AppTheme.ink, fontSize: 30, height: 1.12, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                const Text('Create. Personalize. Send.', style: TextStyle(color: AppTheme.muted, fontSize: 15)),
                const SizedBox(height: 22),
                FilledButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CreateProjectScreen())), icon: const Icon(Icons.add_rounded), label: const Text('Create new certificate project')),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const HistoryScreen())), icon: const Icon(Icons.history_rounded), label: const Text('History'))),
                  const SizedBox(width: 10),
                  Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())), icon: const Icon(Icons.settings_outlined), label: const Text('Settings'))),
                ]),
                const SizedBox(height: 30),
                Row(children: [const Expanded(child: Text('Recent projects', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.ink))), Text('${projects.projects.length}', style: const TextStyle(color: AppTheme.muted))]),
                const SizedBox(height: 12),
                if (projects.error != null) ...[_MessageBanner(message: projects.error!), const SizedBox(height: 12)],
                if (projects.projects.isEmpty) const _EmptyProjects() else ...projects.projects.map((project) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _ProjectCard(project: project))),
              ]),
            ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project});
  final CertificateProject project;
  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ProjectDetailScreen(project: project),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFFE6F2F0), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.workspace_premium_outlined, color: AppTheme.teal)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(project.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.ink)), const SizedBox(height: 3), Text(DateFormat.yMMMd().format(project.updatedAt), style: const TextStyle(color: AppTheme.muted, fontSize: 12))])),
                  const Icon(Icons.chevron_right_rounded, color: AppTheme.muted),
                ]),
                const SizedBox(height: 15),
                Wrap(spacing: 18, runSpacing: 8, children: [
                  _ProjectMetric(label: 'Participants', value: '${project.participants.length}'),
                  _ProjectMetric(label: 'Generated', value: '${project.generatedCount}'),
                  _ProjectMetric(label: 'Sent', value: '${project.sentCount}'),
                  if (project.failedCount > 0) _ProjectMetric(label: 'Failed', value: '${project.failedCount}', alert: true),
                ]),
              ],
            ),
          ),
        ),
      );
}

class _ProjectMetric extends StatelessWidget {
  const _ProjectMetric({required this.label, required this.value, this.alert = false});
  final String label;
  final String value;
  final bool alert;
  @override
  Widget build(BuildContext context) => RichText(text: TextSpan(style: const TextStyle(fontSize: 12, color: AppTheme.muted), children: [TextSpan(text: '$value ', style: TextStyle(fontWeight: FontWeight.w800, color: alert ? const Color(0xFFB5443B) : AppTheme.ink)), TextSpan(text: label)]));
}

class _EmptyProjects extends StatelessWidget {
  const _EmptyProjects();
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30), child: Column(children: [
        const Icon(Icons.description_outlined, size: 38, color: AppTheme.teal),
        const SizedBox(height: 12),
        const Text('Your next event starts here', style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.ink)),
        const SizedBox(height: 6),
        const Text('Create a project to add a template and participant list.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.muted)),
        const SizedBox(height: 14),
        TextButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CreateProjectScreen())), icon: const Icon(Icons.add), label: const Text('Create project')),
      ])));
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFFF1EF), borderRadius: BorderRadius.circular(10)), child: Row(children: [const Icon(Icons.error_outline, color: Color(0xFFB5443B)), const SizedBox(width: 8), Expanded(child: Text(message))]));
}