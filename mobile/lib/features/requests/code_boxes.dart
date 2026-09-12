import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Six single-digit boxes backed by one hidden numeric field, so typing
/// auto-advances and backspace works without juggling focus. Bumping
/// [shake] plays a horizontal shake (wrong code).
class CodeBoxes extends StatefulWidget {
  const CodeBoxes({
    super.key,
    required this.controller,
    this.shake = 0,
    this.enabled = true,
  });

  static const length = 6;

  final TextEditingController controller;
  final int shake;
  final bool enabled;

  @override
  State<CodeBoxes> createState() => _CodeBoxesState();
}

class _CodeBoxesState extends State<CodeBoxes>
    with SingleTickerProviderStateMixin {
  final _focus = FocusNode();
  late final AnimationController _shaker = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  @override
  void didUpdateWidget(CodeBoxes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shake != oldWidget.shake) {
      _shaker.forward(from: 0);
      // The Approve button took focus; bring the keyboard back for retry.
      _focus.requestFocus();
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    _shaker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => _focus.requestFocus(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The real input, kept invisible but focusable.
          Opacity(
            opacity: 0,
            child: SizedBox(
              height: 1,
              child: TextField(
                key: const Key('code-input'),
                controller: widget.controller,
                focusNode: _focus,
                // readOnly rather than enabled: a disabled field drops its
                // IME connection and would not take input again after a
                // wrong-code round trip.
                readOnly: !widget.enabled,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(CodeBoxes.length),
                ],
                showCursor: false,
              ),
            ),
          ),
          AnimatedBuilder(
            animation: Listenable.merge([_shaker, widget.controller, _focus]),
            builder: (context, _) {
              final t = _shaker.value;
              // Damped sine: three wobbles that fade out.
              final dx = t == 0 || t == 1
                  ? 0.0
                  : 12 * (1 - t) * math.sin(t * 3 * 2 * math.pi);
              final text = widget.controller.text;
              return Transform.translate(
                offset: Offset(dx, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < CodeBoxes.length; i++)
                      Container(
                        width: 44,
                        height: 56,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: (_focus.hasFocus && i == text.length)
                                ? scheme.primary
                                : scheme.outline,
                            width: (_focus.hasFocus && i == text.length)
                                ? 2
                                : 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          i < text.length ? text[i] : '',
                          style: const TextStyle(
                            fontSize: 24,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
