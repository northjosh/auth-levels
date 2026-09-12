import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/confirm_dialog.dart';
import '../../core/api/models.dart';
import '../pairing/binding.dart';
import 'push_api.dart';
import 'push_requests.dart';

/// What came of a deny attempt.
sealed class DenyResult {
  const DenyResult();
}

/// The user cancelled the confirmation.
final class DenyCancelled extends DenyResult {
  const DenyCancelled();
}

/// `POST /push/deny` succeeded.
final class Denied extends DenyResult {
  const Denied();
}

/// The request was already gone, or this phone is no longer paired.
final class DenyGone extends DenyResult {
  const DenyGone();
}

/// The call failed (backend down); the request stays open.
final class DenyFailed extends DenyResult {
  const DenyFailed(this.message);
  final String message;
}

/// Confirms, then `POST /push/deny`. On success or when the request is
/// already gone the list is pruned; a transport failure leaves the request
/// open and is reported for the caller to show.
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
  if (!confirmed) return const DenyCancelled();

  final requests = ref.read(pushRequestsProvider.notifier);
  final client = ref.read(apiClientProvider);
  if (client == null) {
    requests.remove(request.requestId);
    return const DenyGone();
  }

  DenyResult result = const Denied();
  try {
    await ref.read(pushApiProvider).deny(client, request.requestId);
  } on ApiError catch (e) {
    if (e.error != ApiError.requestGoneCode) return DenyFailed(e.message);
    result = const DenyGone();
  } on Exception catch (e) {
    return DenyFailed('Something went wrong: $e');
  }
  requests.remove(request.requestId);
  // Let the backend's view catch up with ours.
  unawaited(requests.refresh());
  return result;
}
