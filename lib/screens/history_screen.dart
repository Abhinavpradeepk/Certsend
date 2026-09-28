import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/project_provider.dart';
import '../theme/app_theme.dart';

import 'project_detail_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final projects = context.watch<ProjectProvider>().projects;
    return Scaffold(
        appBar: AppBar(title: const Text('Project history')),
        body: projects.isEmpty
            ? const Center(child: Text('No projects yet.'))
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: projects.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final project = projects[index];
                  return Card(
                      child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: const CircleAvatar(backgroundColor: Color(0xFFE6F2F0), child: Icon(Icons.workspace_premium_outlined, color: AppTheme.teal)),
                    title: Text(project.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${DateFormat.yMMMd().format(project.updatedAt)}  ·  ${project.participants.length} participants\n${project.generatedCount} generated  ·  ${project.sentCount} sent  ·  ${project.failedCount} failed'),
                    isThreeLine: true,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ProjectDetailScreen(project: project),
                      ),
                    ),
                  ));
                }));
  }
}