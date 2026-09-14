import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/relative_time.dart';
import '../../app/router.dart';
import '../../core/api/models.dart';
import '../authenticator/ticker.dart';
import 'request_actions.dart';

/// Dark hero card for one open Push Request, pinned at the top of the
/// Account tab. Review opens the detail; Deny asks first.
class RequestCard extends ConsumerWidget {
  const RequestCard(this.request, {super.key});

  final PushRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final secondsLeft = ref.watch(
      tickerProvider.select(
        (tick) => request.secondsLeft(tick.value ?? DateTime.now()),
      ),
    );
    final onDark = scheme.onInverseSurface;

    return Card(
      color: scheme.inverseSurface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'LOGIN REQUEST',
                    style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.2,
                      color: onDark.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                _CountdownPill(
                  secondsLeft: secondsLeft,
                  urgent: secondsLeft <= PushRequest.urgentSeconds,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              request.client.browserOnOs,
              style: theme.textTheme.titleMedium?.copyWith(color: onDark),
            ),
            Text(
              '${request.client.remoteAddress} · '
              '${relativeTime(request.createdAt)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: onDark.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () =>
                        context.push(Routes.request(request.requestId)),
                    child: const Text('Review'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _deny(context, ref, request),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: onDark,
                    side: BorderSide(color: onDark.withValues(alpha: 0.4)),
                  ),
                  child: const Text('Deny'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Deny from the card: the only feedback needed is when it failed.
Future<void> _deny(
  BuildContext context,
  WidgetRef ref,
  PushRequest request,
) async {
  final result = await denyRequest(context, ref, request);
  if (result case DenyFailed(:final message) when context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text("Couldn't deny: $message")));
  }
}

class _CountdownPill extends StatelessWidget {
  const _CountdownPill({required this.secondsLeft, required this.urgent});

  final int secondsLeft;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: urgent ? scheme.error : scheme.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        minutesSeconds(secondsLeft),
        style: TextStyle(
          color: urgent ? scheme.onError : scheme.onPrimary,
          fontFamily: 'monospace',
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
