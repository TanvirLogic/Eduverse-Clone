import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class InputFieldModule extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? helperText;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final Widget? prefixIcon;

  const InputFieldModule({
    super.key,
    required this.label,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.helperText,
    this.errorText,
    this.onChanged,
    this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabelLabelAtom(label: label),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          style: TextStyle(
            fontSize: 14,
            color: cs.onSurface,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            filled: true,
            prefixIcon: prefixIcon,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
            errorText: errorText,
            errorMaxLines: 2,
            errorStyle: TextStyle(
              fontSize: 11,
              color: cs.error,
              fontWeight: FontWeight.w400,
            ),
            helperText: errorText == null ? helperText : null,
            helperMaxLines: 1,
            helperStyle: TextStyle(
              fontSize: 11,
              color: cs.onSurface.withValues(alpha: 0.5),
              fontWeight: FontWeight.w400,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(color: cs.outlineVariant, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(color: cs.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(color: cs.error, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(color: cs.error, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class FieldLabelLabelAtom extends StatelessWidget {
  final String label;
  const FieldLabelLabelAtom({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 14,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}
