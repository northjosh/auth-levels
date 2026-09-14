import 'package:flutter/material.dart';

/// Small uppercase eyebrow used to head a section of a screen.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        letterSpacing: 1.2,
        color: theme.colorScheme.outline,
      ),
    );
  }
}
