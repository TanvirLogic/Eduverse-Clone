import 'package:flutter/material.dart';
import 'package:edtech/features/profile/edit/presentation/widgets/input_field_module.dart';

class BioFieldModule extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final int maxLength;

  const BioFieldModule({
    super.key,
    required this.label,
    required this.controller,
    this.maxLength = 300,
  });

  @override
  State<BioFieldModule> createState() => _BioFieldModuleState();
}

class _BioFieldModuleState extends State<BioFieldModule> {
  int _charCount = 0;

  @override
  void initState() {
    super.initState();
    _charCount = widget.controller.text.length;
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final newCount = widget.controller.text.length;
    if (newCount != _charCount) {
      setState(() => _charCount = newCount);
    }
  }

  Color _counterColor(int count, int max) {
    final cs = Theme.of(context).colorScheme;
    if (count >= max) return cs.error;
    if (count >= max * 0.8) return cs.error.withValues(alpha: 0.7);
    return cs.onSurface.withValues(alpha: 0.5);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final count = _charCount;
    final max = widget.maxLength;
    final counterColor = _counterColor(count, max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            FieldLabelLabelAtom(label: widget.label),
            Text(
              "$count/$max",
              style: TextStyle(
                color: counterColor,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          textInputAction: TextInputAction.done,
          controller: widget.controller,
          maxLines: 4,
          maxLength: max,
          style: TextStyle(fontSize: 14, color: cs.onSurface),
          decoration: InputDecoration(
            hintText: "Tell us about yourself...",
            hintStyle: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.5),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            filled: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
            counterText: "",
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: cs.outlineVariant, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: count >= max ? cs.error : cs.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
