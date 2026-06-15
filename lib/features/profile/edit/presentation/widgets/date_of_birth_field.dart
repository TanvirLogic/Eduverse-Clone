import 'package:flutter/material.dart';
import 'package:edtech/features/profile/edit/presentation/widgets/input_field_module.dart';

class DateOfBirthField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onTap;
  final String? errorText;

  const DateOfBirthField({
    super.key,
    required this.controller,
    required this.onTap,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabelLabelAtom(label: "Date of birth"),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: true,
          onTap: onTap,
          style: TextStyle(
            fontSize: 14,
            color: cs.onSurface,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: "Select your Date of Birth",
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
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                Icons.calendar_today_outlined,
                size: 20,
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
            ),
            errorText: errorText,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(color: cs.outlineVariant, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(color: cs.primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
