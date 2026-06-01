import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../../theme/app_theme.dart';

/// Display block for free-form text (notes, decisions, addresses…).
/// Auto-detects RTL/LTR and collapses with "show more / less" when
/// the content is long, so the surrounding card stays compact.
class LongTextBlock extends StatefulWidget {
  final String label;
  final String text;
  final Color accent;
  final int collapsedLines;
  const LongTextBlock({
    super.key,
    required this.label,
    required this.text,
    this.accent = AppColors.navy,
    this.collapsedLines = 3,
  });

  @override
  State<LongTextBlock> createState() => _LongTextBlockState();
}

class _LongTextBlockState extends State<LongTextBlock> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isRtl = widget.text.isEmpty
        ? true
        : intl.Bidi.detectRtlDirectionality(widget.text);
    final align = isRtl ? TextAlign.right : TextAlign.left;
    final dir = isRtl ? TextDirection.rtl : TextDirection.ltr;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.offWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          right: BorderSide(color: widget.accent, width: 3),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: TextStyle(
              color: widget.accent,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            child: Text(
              widget.text,
              textAlign: align,
              textDirection: dir,
              maxLines: _expanded ? null : widget.collapsedLines,
              overflow: _expanded ? null : TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                height: 1.6,
                color: AppColors.ink,
              ),
            ),
          ),
          if (_isLong())
            TextButton.icon(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                minimumSize: const Size(0, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(
                _expanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 18,
              ),
              label: Text(_expanded ? 'إخفاء' : 'عرض المزيد'),
            ),
        ],
      ),
    );
  }

  bool _isLong() => widget.text.length > 120 || '\n'.allMatches(widget.text).length >= widget.collapsedLines;
}
