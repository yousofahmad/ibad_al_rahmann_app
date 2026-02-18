import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import 'gradient_icons.dart';

/// A small reusable card used in the services grid.
/// Displays a gradient icon and a title, and notifies via [onTap] when tapped.
/// Intended for use on the HomeScreen to represent app features (e.g. أذكار الصباح).
class ServiceCard extends StatelessWidget {
  final String name;
  final IconData icon;
  final VoidCallback onTap;

  const ServiceCard({
    super.key,
    required this.name,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Handle tap events coming from the parent
      onTap: onTap,
      child: Container(
        // Card visual styling: white background, rounded corners, subtle shadow
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              // subtle drop shadow to lift the card from the background
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Custom gradient icon widget (keeps visual style consistent)
            GradientIcon(icon, size: 35),
            const SizedBox(height: 12),
            // Service title shown below the icon
            Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryGold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
