import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

class CertiSendApp extends StatelessWidget {
  const CertiSendApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'CertiSend',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const HomeScreen(),
      );
}