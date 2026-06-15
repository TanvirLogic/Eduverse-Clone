import 'package:edtech/app/app_colors.dart';
import 'package:edtech/global/core/constants/sizes.dart';
import 'package:flutter/material.dart';

class CourseEditFormContent extends StatelessWidget {
  final TextEditingController titleCtrl;
  final TextEditingController shortDescCtrl;
  final TextEditingController descCtrl;
  final TextEditingController reqCtrl;
  final TextEditingController priceCtrl;
  final String selectedLanguage;
  final String selectedLevel;
  final String courseType;
  final ValueChanged<String?> onLanguageChanged;
  final ValueChanged<String?> onLevelChanged;
  final ValueChanged<String> onTypeChanged;
  final bool showPrice;

  const CourseEditFormContent({
    super.key,
    required this.titleCtrl,
    required this.shortDescCtrl,
    required this.descCtrl,
    required this.reqCtrl,
    required this.priceCtrl,
    required this.selectedLanguage,
    required this.selectedLevel,
    required this.courseType,
    required this.onLanguageChanged,
    required this.onLevelChanged,
    required this.onTypeChanged,
    this.showPrice = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildLabel('Title', cs),
        const SizedBox(height: 8),
        TextFormField(
          controller: titleCtrl,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          style: TextStyle(color: cs.onSurface),
          decoration: _inputDecoration(cs, 'Enter your course title'),
        ),
        const SizedBox(height: 16),
        _buildLabel('Short Description', cs),
        const SizedBox(height: 8),
        TextFormField(
          controller: shortDescCtrl,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          style: TextStyle(color: cs.onSurface),
          decoration: _inputDecoration(cs, 'Enter short description'),
        ),
        const SizedBox(height: 16),
        _buildLabel('Description', cs),
        const SizedBox(height: 8),
        TextFormField(
          controller: descCtrl,
          maxLines: 4,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          style: TextStyle(color: cs.onSurface),
          decoration: _inputDecoration(cs, 'Enter your description'),
        ),
        const SizedBox(height: 16),
        _buildLabel('Requirements', cs),
        const SizedBox(height: 8),
        TextFormField(
          controller: reqCtrl,
          maxLines: 4,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          style: TextStyle(color: cs.onSurface),
          decoration: _inputDecoration(cs, 'Enter your requirements'),
        ),
        const SizedBox(height: 16),
        _buildLabel('Language', cs),
        const SizedBox(height: 8),
        _buildDropdownField(
          cs,
          selectedLanguage,
          ['English', 'Bangla', 'Spanish', 'Arabic', 'Hindi'],
          onLanguageChanged,
        ),
        const SizedBox(height: 16),
        _buildLabel('Level', cs),
        const SizedBox(height: 8),
        _buildDropdownField(
          cs,
          selectedLevel,
          ['BEGINNER', 'INTERMEDIATE', 'ADVANCED'],
          onLevelChanged,
        ),
        const SizedBox(height: 16),
        _buildLabel('Type', cs),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildRadioTile(cs, 'FREE', courseType, onTypeChanged, isDark)),
            const SizedBox(width: 16),
            Expanded(child: _buildRadioTile(cs, 'PAID', courseType, onTypeChanged, isDark)),
          ],
        ),
        if (showPrice && courseType == 'PAID') ...[
          const SizedBox(height: 16),
          _buildLabel('Price', cs),
          const SizedBox(height: 8),
          TextFormField(
            controller: priceCtrl,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            style: TextStyle(color: cs.onSurface),
            decoration: _inputDecoration(cs, 'Enter price'),
          ),
        ],
      ],
    );
  }

  Widget _buildLabel(String text, ColorScheme cs, {bool required = true}) {
    return RichText(
      text: TextSpan(
        text: text,
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: cs.onSurface),
        children: [
          if (required)
            const TextSpan(text: ' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(ColorScheme cs, String hint) {
    final isDark = cs.brightness == Brightness.dark;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.5), fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusDef),
        borderSide: BorderSide(color: isDark ? cs.outlineVariant : AppColors.border, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusDef),
        borderSide: BorderSide(color: AppColors.themeColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusDef),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusDef),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
    );
  }

  Widget _buildDropdownField(
    ColorScheme cs,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    final isDark = cs.brightness == Brightness.dark;
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: items.map((item) {
        return DropdownMenuItem<String>(value: item, child: Text(item, style: TextStyle(color: cs.onSurface)));
      }).toList(),
      onChanged: onChanged,
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: cs.onSurface.withValues(alpha: 0.5)),
      style: TextStyle(color: cs.onSurface, fontSize: 15, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusDef),
          borderSide: BorderSide(color: isDark ? cs.outlineVariant : AppColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusDef),
          borderSide: BorderSide(color: AppColors.themeColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusDef),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusDef),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        filled: true,
        fillColor: isDark ? cs.surfaceContainerHighest : Colors.white,
      ),
      dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
    );
  }

  Widget _buildRadioTile(ColorScheme cs, String type, String selectedType, ValueChanged<String> onChanged, bool isDark) {
    final isSelected = selectedType == type;
    return InkWell(
      onTap: () => onChanged(type),
      borderRadius: BorderRadius.circular(AppSizes.radiusDef),
      child: Ink(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isDark ? cs.surfaceContainerHighest : Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radiusDef),
          border: Border.all(
            color: isDark ? cs.outlineVariant : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? AppColors.themeColor : cs.onSurface.withValues(alpha: 0.5),
              size: 22,
            ),
            const SizedBox(width: 12),
            Text(
              type,
              style: TextStyle(
                color: isSelected ? cs.onSurface : cs.onSurface.withValues(alpha: 0.5),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
