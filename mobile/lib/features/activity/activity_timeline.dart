import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/relative_time.dart';
import '../../app/section_label.dart';
import '../../core/api/models.dart';
import 'event_presentation.dart';
import 'security_events.dart';

/// The Activity section of the paired Account tab, as list children (the
/// tab owns the scrolling ListView so pull-to-refresh covers everything).
/// Returns the heading, then rows, then a load-more sentinel or footer.
List<Widget> activityTimelineChildren(BuildContext context, WidgetRef ref) {
  final theme = Theme.of(context);
  final events = ref.watch(securityEventsProvider);
  return [
    const SectionLabel('Activity'),
    const SizedBox(height: 12),
    ...switch (events) {
      AsyncData(:final value) when value.items.isEmpty => [
        Text('No activity yet.', style: theme.textTheme.bodySmall),
      ],
      AsyncData(:final value) => [
        for (final event in value.items)
          ActivityRow(event, key: ValueKey(event.id)),
        if (value.hasMore)
          _LoadMore(loading: value.loadingMore)
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'That is everything.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
      ],
      AsyncError() => [
        Text(
          "Couldn't load activity. Pull to try again.",
          style: theme.textTheme.bodySmall,
        ),
      ],
      _ => const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
    },
  ];
}

class ActivityRow extends StatelessWidget {
  const ActivityRow(this.event, {super.key});

  final SecurityEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final view = presentEvent(event);
    final subtitle = eventSubtitle(event);
    final tint = view.negative ? scheme.error : null;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(view.icon, color: tint ?? scheme.outline),
      title: Text(
        view.title,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: tint,
          fontFamily: view.rawType ? 'monospace' : null,
        ),
      ),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: Text(
        relativeTime(event.occurredAt),
        style: theme.textTheme.bodySmall,
      ),
    );
  }
}

/// Asks for the next page as soon as it scrolls into view. The list keys
/// its children by index, so after a page lands this sentinel is rebuilt
/// at its new index and fires again; after a failed page it stays put and
/// the button is the retry.
class _LoadMore extends ConsumerStatefulWidget {
  const _LoadMore({required this.loading});

  final bool loading;

  @override
  ConsumerState<_LoadMore> createState() => _LoadMoreState();
}

class _LoadMoreState extends ConsumerState<_LoadMore> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(securityEventsProvider.notifier).loadMore();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: widget.loading
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(
                onPressed: () =>
                    ref.read(securityEventsProvider.notifier).loadMore(),
                child: const Text('Load older'),
              ),
      ),
    );
  }
}
