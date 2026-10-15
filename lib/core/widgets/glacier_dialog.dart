import 'package:flutter/material.dart';

class GlacierDialog extends StatelessWidget {
  const GlacierDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.maxWidth = 640,
    this.insetPadding = const EdgeInsets.symmetric(
      horizontal: 20,
      vertical: 24,
    ),
    this.titlePadding,
    this.contentPadding,
    this.actionsPadding,
    this.buttonPadding,
  });

  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final double maxWidth;
  final EdgeInsets insetPadding;
  final EdgeInsetsGeometry? titlePadding;
  final EdgeInsetsGeometry? contentPadding;
  final EdgeInsetsGeometry? actionsPadding;
  final EdgeInsetsGeometry? buttonPadding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: insetPadding,
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh.withValues(
            alpha: isDark ? 0.96 : 0.98,
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: scheme.outlineVariant.withValues(
              alpha: isDark ? 0.42 : 0.62,
            ),
          ),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: AlertDialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            titlePadding: titlePadding,
            contentPadding: contentPadding,
            actionsPadding: actionsPadding,
            buttonPadding: buttonPadding,
            title: title,
            content: content,
            actions: actions,
          ),
        ),
      ),
    );
  }
}
