import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/confirm_dialog.dart';
import '../../core/api/models.dart';
import '../pairing/binding.dart';
import 'push_api.dart';
import 'push_requests.dart';

/// What came of a deny attempt.
enum DenyResult {
  /// The user cancelled, or the call failed and the request stays open.
  notDenied,

  /// `POST /push/deny` succeeded.
  denied,

  /// The request was already gone, or this phone is no longer paired.
  gone,
}

/// Confirms, then `POST /push/deny`. On success or when the request is
/// already gone the list is pruned; a transport failure is reported and
/// leaves the request open.
Future<DenyResult> denyRequest(
  BuildContext context,
  WidgetRef ref,
  PushRequest request,
) async {
  final confirmed = await confirmDialog(
    context,
    title: 'Deny this login?',
    body:
        'The sign-in from ${request.client.browserOnOs} at '
        '${request.client.remoteAddress} will be refused.',
    action: 'Deny',
  );
  if (!confirmed) return DenyResult.notDenied;

  final requests = ref.read(pushRequestsProvider.notifier);
  final client = ref.read(apiClientProvider);
  if (client == null) {
    requests.remove(request.requestId);
    return DenyResult.gone;
  }

  var result = DenyResult.denied;
  try {
    await ref.read(pushApiProvider).deny(client, request.requestId);
  } on ApiError catch (e) {
    if (e.error != ApiError.requestGoneCode) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Couldn't deny: ${e.message}")));
      }
      return DenyResult.notDenied;
    }
    result = DenyResult.gone;
  }
  requests.remove(request.requestId);
  // Let the backend's view catch up with ours.
  unawaited(requests.refresh());
  return result;
}

void unawaited(Future<void> future) {}
