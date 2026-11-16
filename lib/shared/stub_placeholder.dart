import 'package:flutter/material.dart';

/// Заглушка нереализованного экрана: показывает, какая фаза roadmap закрывает раздел.
class StubPlaceholder extends StatelessWidget {
  const StubPlaceholder({super.key, required this.title, required this.phase});

  final String title;
  final String phase;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.construction_outlined, size: 48),
              const SizedBox(height: 16),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(phase, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}
