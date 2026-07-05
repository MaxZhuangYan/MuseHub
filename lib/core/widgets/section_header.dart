import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.action,
    super.key,
  });

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.sora(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
                letterSpacing: -0.4,
              ),
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}
