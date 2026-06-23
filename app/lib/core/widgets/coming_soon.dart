import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';

/// Temporary placeholder for routes still on the build-order backlog (§10).
/// Replaced feature-by-feature; keeps the app navigable in the meantime.
class ComingSoon extends StatelessWidget {
  const ComingSoon({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: context.canPop()
            ? IconButton(icon: const BackButtonIcon(), onPressed: () => context.pop())
            : IconButton(icon: const Icon(Icons.home), onPressed: () => context.go('/home')),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.construction, size: 48, color: AppTokens.textSecondary),
              const SizedBox(height: AppTokens.s12),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppTokens.s4),
              const Text('Coming soon', style: TextStyle(color: AppTokens.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}
