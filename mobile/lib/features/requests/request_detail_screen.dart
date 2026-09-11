import 'package:flutter/material.dart';

/// Push Request detail, reached from a notification tap or a hero card.
/// Placeholder until ticket 07; the route exists so deep links resolve.
class RequestDetailScreen extends StatelessWidget {
  const RequestDetailScreen({super.key, required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login request')),
      body: Center(
        child: Text(
          'Request $requestId',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
