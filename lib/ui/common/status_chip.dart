import 'package:flutter/material.dart';

import '../../models/legal_case.dart';
import '../../models/session.dart';
import '../../theme/app_theme.dart';

class StatusChip extends StatelessWidget {
  final String value;
  const StatusChip(this.value, {super.key});

  Color _color() {
    switch (value) {
      case LegalCase.statusOpen:
      case CaseSession.statusPending:
        return AppColors.warn;
      case LegalCase.statusInProgress:
      case CaseSession.statusHeld:
        return AppColors.navy;
      case LegalCase.statusClosed:
      case CaseSession.statusCancelled:
        return Colors.black54;
      case LegalCase.statusJudged:
        return AppColors.success;
      case CaseSession.statusAdjourned:
        return AppColors.danger;
    }
    return AppColors.navy;
  }

  @override
  Widget build(BuildContext context) {
    final c = _color();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.5)),
      ),
      child: Text(
        value,
        style: TextStyle(
          color: c,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}
