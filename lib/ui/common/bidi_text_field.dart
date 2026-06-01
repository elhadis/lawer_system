import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../../theme/app_theme.dart';

/// Multi-line text field that automatically follows the direction of its
/// content (RTL for Arabic, LTR for Latin) so paragraphs always read
/// correctly. Designed for notes, decisions, contract bodies, etc.
class BidiTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final int minLines;
  final int maxLines;
  final bool document;
  final FormFieldValidator<String>? validator;
  final EdgeInsetsGeometry? contentPadding;

  const BidiTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.minLines = 4,
    this.maxLines = 8,
    this.document = false,
    this.validator,
    this.contentPadding,
  });

  @override
  State<BidiTextField> createState() => _BidiTextFieldState();
}

class _BidiTextFieldState extends State<BidiTextField> {
  TextDirection _direction = TextDirection.rtl;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateDirection);
    _updateDirection();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateDirection);
    super.dispose();
  }

  void _updateDirection() {
    final text = widget.controller.text;
    final detected = text.isEmpty
        ? TextDirection.rtl
        : intl.Bidi.detectRtlDirectionality(text)
            ? TextDirection.rtl
            : TextDirection.ltr;
    if (detected != _direction && mounted) {
      setState(() => _direction = detected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final field = TextFormField(
      controller: widget.controller,
      validator: widget.validator,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      textAlignVertical: TextAlignVertical.top,
      textDirection: _direction,
      textAlign:
          _direction == TextDirection.rtl ? TextAlign.right : TextAlign.left,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      style: TextStyle(
        fontSize: widget.document ? 14.5 : 14,
        height: widget.document ? 1.9 : 1.55,
        color: AppColors.ink,
      ),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        alignLabelWithHint: true,
        contentPadding: widget.contentPadding ??
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: widget.document
            ? InputBorder.none
            : OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
        enabledBorder: widget.document
            ? InputBorder.none
            : OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
        focusedBorder: widget.document
            ? InputBorder.none
            : OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.gold, width: 1.6),
              ),
      ),
    );

    if (!widget.document) return field;

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
            boxShadow: const [
              BoxShadow(
                blurRadius: 12,
                offset: Offset(0, 2),
                color: Color(0x14001F3F),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(22, 30, 22, 22),
          child: field,
        ),
        Positioned(
          top: 0,
          right: 14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.description_rounded,
                    color: AppColors.navy, size: 14),
                const SizedBox(width: 4),
                Text(
                  widget.label,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
