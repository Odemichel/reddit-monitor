import 'package:flutter/material.dart';

enum ItemStatus {
  nouveau,
  aSuivre,
  enCours,
  traite,
  ignore;

  String get label => switch (this) {
    nouveau => 'Nouveau',
    aSuivre => 'À suivre',
    enCours => 'En cours',
    traite => 'Traité',
    ignore => 'Ignoré',
  };

  Color get color => switch (this) {
    nouveau => const Color(0xFF60A5FA),
    aSuivre => const Color(0xFFFBBF24),
    enCours => const Color(0xFFA78BFA),
    traite => const Color(0xFF34D399),
    ignore => const Color(0xFF6B7280),
  };

  IconData get icon => switch (this) {
    nouveau => Icons.fiber_new_rounded,
    aSuivre => Icons.bookmark_outline_rounded,
    enCours => Icons.pending_outlined,
    traite => Icons.check_circle_outline_rounded,
    ignore => Icons.visibility_off_outlined,
  };
}
