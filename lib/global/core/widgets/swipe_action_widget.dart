import 'package:edtech/global/core/constants/sizes.dart';
import 'package:edtech/app/app_colors.dart';
import 'package:flutter/material.dart';

class SwipeActionWidget extends StatefulWidget {
  final Widget child;
  final Future<bool> Function()? onDelete;
  final VoidCallback? onEdit;
  final ValueNotifier<int>? resetNotifier;
  final Widget? editIcon;
  final ValueNotifier<bool>? revealNotifier;

  const SwipeActionWidget({
    super.key,
    required this.child,
    this.onDelete,
    this.onEdit,
    this.resetNotifier,
    this.editIcon,
    this.revealNotifier,
  });

  @override
  State<SwipeActionWidget> createState() => _SwipeActionWidgetState();
}

class _SwipeActionWidgetState extends State<SwipeActionWidget> {
  double _offset = 0;
  bool _isDragging = false;

  static const double _threshold = 0.175;

  @override
  void initState() {
    super.initState();
    widget.resetNotifier?.addListener(_onReset);
  }

  @override
  void didUpdateWidget(SwipeActionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.resetNotifier != oldWidget.resetNotifier) {
      oldWidget.resetNotifier?.removeListener(_onReset);
      widget.resetNotifier?.addListener(_onReset);
    }
  }

  @override
  void dispose() {
    widget.resetNotifier?.removeListener(_onReset);
    super.dispose();
  }

  void _setOffset(double value) {
    _offset = value;
    widget.revealNotifier?.value = _offset != 0;
  }

  void _onReset() {
    if (_offset != 0 && mounted) {
      setState(() => _setOffset(0));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxReveal = constraints.maxWidth * _threshold;
        final hasDelete = widget.onDelete != null;
        final hasEdit = widget.onEdit != null;

        return SizedBox(
          width: constraints.maxWidth,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedPadding(
                padding: EdgeInsets.only(
                  right: _offset < 0 ? -_offset : 0,
                  left: _offset > 0 ? _offset : 0,
                ),
                duration: _isDragging ? Duration.zero : const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: GestureDetector(
                  onHorizontalDragStart: (_) => _isDragging = true,
                  onHorizontalDragUpdate: (d) {
                    setState(() {
                      final minOffset = hasDelete ? -maxReveal : 0.0;
                      final maxOffset = hasEdit ? maxReveal : 0.0;
                      _setOffset((_offset + d.delta.dx).clamp(minOffset, maxOffset));
                    });
                  },
                  onHorizontalDragEnd: (_) {
                    _isDragging = false;
                    setState(() {
                      _setOffset(_offset.abs() > maxReveal * 0.3
                          ? (_offset < 0 ? -maxReveal : maxReveal)
                          : 0);
                    });
                  },
                  child: widget.child,
                ),
              ),
              if (hasDelete && _offset < 0)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: maxReveal,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () async {
                      final confirmed = await widget.onDelete!();
                      if (confirmed && mounted) {
                        setState(() => _setOffset(0));
                      }
                    },
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: cs.error.withValues(alpha: 0.1),
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(AppSizes.radiusSm),
                          bottomRight: Radius.circular(AppSizes.radiusSm),
                        ),
                      ),
                      child: Icon(Icons.delete_outline, color: cs.error, size: 28),
                    ),
                  ),
                ),
              if (hasEdit && _offset > 0)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: maxReveal,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      widget.onEdit!();
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _setOffset(0));
                      });
                    },
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.themeColor.withValues(alpha: 0.1),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(AppSizes.radiusSm),
                          bottomLeft: Radius.circular(AppSizes.radiusSm),
                        ),
                      ),
                      child: widget.editIcon ?? Icon(Icons.edit, color: AppColors.themeColor, size: 28),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
