import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;
  
  const AppLogo({
    super.key,
    this.size = 80,
  });

  @override
  Widget build(BuildContext context) {
    // We use the theme's brightness to decide which logo to show
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Logo - black (logo_black.png) for light theme (white systems)
    // Logo - white (logo_white.png) for dark theme (black systems)
    final assetPath = isDark 
        ? 'assets/logos/logo_white.png' 
        : 'assets/logos/logo_black.png';

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.2), // Increased from 0.1 to 0.2 to prevent clipping
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      child: Center(
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
          key: ValueKey(assetPath), 
        ),
      ),
    );
  }
}
