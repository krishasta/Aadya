import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';

/// Interactive Header Button to toggle between Light and Dark modes.
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeService.instance,
      builder: (context, _) {
        final isDark = ThemeService.instance.isDark;
        final iconColor = isDark ? AppTheme.darkPrimary : AppTheme.primaryBlue;
        final bgColor = isDark ? AppTheme.darkPrimarySoft : AppTheme.primaryBlueSoft;
        final borderColor = isDark ? AppTheme.darkBorder : AppTheme.primaryBlueBorder;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => ThemeService.instance.toggleTheme(),
              child: Tooltip(
                message: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor, width: 1.2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, anim) => RotationTransition(
                          turns: anim,
                          child: FadeTransition(opacity: anim, child: child),
                        ),
                        child: Icon(
                          isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                          key: ValueKey<bool>(isDark),
                          size: 16,
                          color: iconColor,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isDark ? 'Dark' : 'Light',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: iconColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
