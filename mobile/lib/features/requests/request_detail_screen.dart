import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/relative_time.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/api/models.dart';
import '../../core/notifications/push_notifications.dart';
import '../authenticator/ticker.dart';
import '../pairing/binding.dart';
import 'code_boxes.dart';
import 'push_api.dart';
import 'push_requests.dart';
import 'request_actions.dart';

/// Where a Push Request ends up once this screen is done with it.
enum _Outcome { approved, denied, gone }

/// Push Request detail (`/requests/:requestId`): countdown, requester
/// facts, Number Matching code entry, Approve / Deny. Reached from a hero
/// card, a notification, or a deep link — an unknown id shows the gone
/// state, never an error.
class RequestDetailScreen extends ConsumerStatefulWidget {
  const RequestDetailScreen({super.key, required this.requestId});

  final String requestId;

  static const initialAttempts = 3;
  static const outcomeDelay = Duration(seconds: 1);

  @override
  ConsumerState<RequestDetailScreen> createState() =>
      _RequestDetailScreenState();
}

class _RequestDetailScreenState extends ConsumerState<RequestDetailScreen> {
  final _code = TextEditingController();
  var _attemptsLeft = RequestDetailScreen.initialAttempts;
  var _shake = 0;
  var _busy = false;
  String? _error;
  _Outcome? _outcome;
  Timer? _leaveTimer;

  @override
  void dispose() {
    _code.dispose();
    _leaveTimer?.cancel();
    super.dispose();
  }

  PushRequest? _find(List<PushRequest> requests) {
    for (final r in requests) {
      if (r.requestId == widget.requestId) return r;
    }
    return null;
  }

  /// Back to the Account tab, whatever is underneath: a hero card push, a
  /// notification tap over the Codes tab, or a cold start with nothing.
  void _leave() {
    if (mounted) context.go(Routes.account);
  }

  @override
  void initState() {
    super.initState();
    // Opened, so its tray notification has done its job.
    _dismissNotification();
  }

  void _dismissNotification() => unawaited(
    ref.read(pushNotificationsProvider).cancelFor(widget.requestId),
  );

  void _finish(_Outcome outcome) {
    if (_outcome != null) return;
    setState(() => _outcome = outcome);
    _dismissNotification();
    final requests = ref.read(pushRequestsProvider.notifier)
      ..remove(widget.requestId);
    if (outcome == _Outcome.gone) return;
    // Approve / deny already asked the backend; pull its view of the list.
    unawaited(requests.refresh());
    _leaveTimer = Timer(RequestDetailScreen.outcomeDelay, _leave);
  }

  Future<void> _approve() async {
    final client = ref.read(apiClientProvider);
    if (client == null) return _finish(_Outcome.gone);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(pushApiProvider)
          .verify(client, widget.requestId, _code.text);
      if (mounted) _finish(_Outcome.approved);
    } on ApiError catch (e) {
      if (!mounted) return;
      if (e.isRequestGone || e.attemptsLeft == 0) {
        _finish(_Outcome.gone);
      } else if (e.error == ApiError.otpMismatchCode) {
        final left = e.attemptsLeft ?? (_attemptsLeft - 1);
        setState(() {
          _attemptsLeft = left;
          _shake++;
          _code.clear();
        });
      } else {
        setState(() => _error = e.message);
      }
    } on Exception catch (e) {
      // A malformed reply is an error to show, not a crash.
      if (mounted) setState(() => _error = 'Something went wrong: $e');
    } finally {
      if (mounted && _outcome == null) setState(() => _busy = false);
    }
  }

  Future<void> _deny(PushRequest request) async {
    final result = await denyRequest(context, ref, request);
    if (!mounted) return;
    switch (result) {
      case Denied():
        _finish(_Outcome.denied);
      case DenyGone():
        _finish(_Outcome.gone);
      case DenyFailed(:final message):
        setState(() => _error = message);
      case DenyCancelled():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final requests = ref.watch(pushRequestsProvider);
    final now = ref.watch(tickerProvider).value ?? DateTime.now();

    final Widget body;
    if (_outcome != null) {
      body = _OutcomeView(_outcome!, onLeave: _leave);
    } else {
      switch (requests) {
        case AsyncData(:final value):
          final request = _find(value);
          // Missing from the list, or run out: gone. Purely derived, so
          // the list is left to the next refresh.
          body = (request == null || !request.isOpen(now))
              ? _OutcomeView(_Outcome.gone, onLeave: _leave)
              : _PendingView(
                  request: request,
                  now: now,
                  code: _code,
                  attemptsLeft: _attemptsLeft,
                  shake: _shake,
                  busy: _busy,
                  error: _error,
                  onApprove: _approve,
                  onDeny: () => _deny(request),
                );
        case AsyncError(:final error):
          body = _LoadFailedView(
            message: error is ApiError
                ? error.message
                : "Couldn't load this request.",
            onRetry: () => ref.read(pushRequestsProvider.notifier).refresh(),
            onLeave: _leave,
          );
        default:
          body = const Center(child: CircularProgressIndicator());
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Login request')),
      body: body,
    );
  }
}

class _PendingView extends StatelessWidget {
  const _PendingView({
    required this.request,
    required this.now,
    required this.code,
    required this.attemptsLeft,
    required this.shake,
    required this.busy,
    required this.error,
    required this.onApprove,
    required this.onDeny,
  });

  final PushRequest request;
  final DateTime now;
  final TextEditingController code;
  final int attemptsLeft;
  final int shake;
  final bool busy;
  final String? error;
  final VoidCallback onApprove;
  final VoidCallback onDeny;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final secondsLeft = request.secondsLeft(now);
    final localizations = MaterialLocalizations.of(context);
    final requestedAt = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(request.createdAt.toLocal()),
    );

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: Text(
            minutesSeconds(secondsLeft),
            style: theme.textTheme.displayMedium?.copyWith(
              fontFamily: 'monospace',
              fontFeatures: const [FontFeature.tabularFigures()],
              color: request.isUrgent(now) ? scheme.error : null,
            ),
          ),
        ),
        Center(
          child: Text(
            'until this request expires',
            style: theme.textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 24),
        _Fact('Browser', request.client.browserOnOs),
        _Fact('Device', request.client.deviceFamily),
        _Fact('Address', request.client.remoteAddress),
        _Fact(
          'Requested',
          '$requestedAt · ${relativeTime(request.createdAt, now: now)}',
        ),
        const SizedBox(height: 24),
        Text(
          'Enter the code shown on that screen',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        CodeBoxes(controller: code, shake: shake, enabled: !busy),
        const SizedBox(height: 8),
        Text(
          attemptsLeft == 1 ? '1 attempt left' : '$attemptsLeft attempts left',
          style: theme.textTheme.bodySmall?.copyWith(
            color: attemptsLeft == 1 ? scheme.error : null,
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(error!, style: TextStyle(color: scheme.error)),
        ],
        const SizedBox(height: 24),
        ValueListenableBuilder(
          valueListenable: code,
          builder: (context, value, _) => FilledButton(
            onPressed: (busy || value.text.length < CodeBoxes.length)
                ? null
                : onApprove,
            style: FilledButton.styleFrom(
              backgroundColor: approveGreen,
              foregroundColor: Colors.white,
            ),
            child: busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Approve login'),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: busy ? null : onDeny,
          style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
          child: const Text('Deny'),
        ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _OutcomeView extends StatelessWidget {
  const _OutcomeView(this.outcome, {required this.onLeave});

  final _Outcome outcome;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color, title, subtitle) = switch (outcome) {
      _Outcome.approved => (
        Icons.check_circle,
        approveGreen,
        'Approved',
        'The login is going through.',
      ),
      _Outcome.denied => (
        Icons.block,
        theme.colorScheme.error,
        'Denied',
        'That sign-in was refused.',
      ),
      _Outcome.gone => (
        Icons.hourglass_disabled,
        theme.colorScheme.outline,
        'Request gone',
        'This request expired or was already handled.',
      ),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: color),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(subtitle, textAlign: TextAlign.center),
            if (outcome == _Outcome.gone) ...[
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onLeave,
                child: const Text('Back to Account'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LoadFailedView extends StatelessWidget {
  const _LoadFailedView({
    required this.message,
    required this.onRetry,
    required this.onLeave,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
            TextButton(
              onPressed: onLeave,
              child: const Text('Back to Account'),
            ),
          ],
        ),
      ),
    );
  }
}
