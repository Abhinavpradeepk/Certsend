import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Settings')), body: ListView(padding: const EdgeInsets.all(20), children: const [
        _SectionHeading('Appearance'),
        Card(child: ListTile(leading: Icon(Icons.brightness_auto_outlined, color: AppTheme.ocean), title: Text('Theme'), subtitle: Text('System default'))),
        SizedBox(height: 22),
        _SectionHeading('Defaults'),
        Card(child: ListTile(leading: Icon(Icons.tag_rounded, color: AppTheme.ocean), title: Text('Certificate ID prefix'), subtitle: Text('CERT'))),
        Card(child: ListTile(leading: Icon(Icons.mail_outline_rounded, color: AppTheme.ocean), title: Text('Default sender name'), subtitle: Text('Not configured'))),
        SizedBox(height: 22),
        _SectionHeading('About'),
        Card(child: ListTile(leading: Icon(Icons.workspace_premium_outlined, color: AppTheme.ocean), title: Text('CertiSend'), subtitle: Text('Version 1.0.0'))),
      ]));
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(left: 2, bottom: 10), child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.ink)));
}