import 'package:flutter/material.dart';

import 'shared/theme.dart';
import 'ui/role_gate.dart';

class DndApp extends StatelessWidget {
  const DndApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'D&D Помощник',
        theme: AppTheme.dark,
        home: const RoleGateScreen(),
        debugShowCheckedModeBanner: false,
      );
}
