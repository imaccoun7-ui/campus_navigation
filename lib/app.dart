import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';

/// Root widget: one router, one theme built from design tokens.
class CampusNavApp extends ConsumerWidget {
  const CampusNavApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Campus Nav',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      // Text scaling is deliberately left to the device setting.
      routerConfig: router,
    );
  }
}
