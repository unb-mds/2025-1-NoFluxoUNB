import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:go_router/go_router.dart';

class AppHeader extends StatelessWidget {
  final VoidCallback onMenuPressed;

  const AppHeader({
    Key? key,
    required this.onMenuPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Logo
              GestureDetector(
                onTap: () {
                  // Navigate to home instead of fluxogramas
                  context.go('/');
                },
                child: const Text(
                  'NOFLX UNB',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Permanent Marker',
                  ),
                ),
              ),

              // Desktop Navigation
              if (MediaQuery.of(context).size.width > 768)
                Row(
                  children: [
                    _NavItem(
                      title: 'HOME',
                      onTap: () => context.go('/'),
                    ),
                    const SizedBox(width: 32),
                    _NavItem(
                      title: 'FLUXOGRAMAS',
                      onTap: () => context.go('/fluxogramas'),
                    ),
                    const SizedBox(width: 32),
                    _NavItem(
                      title: 'SOBRE NÓS',
                      onTap: () => context.go('/#sobre'),
                    ),
                    const SizedBox(width: 32),
                    _NavItem(
                      title: 'ASSISTENTE',
                      onTap: () => context.go('/assistente'),
                    ),
                  ],
                ),

              // Mobile Menu Button
              if (MediaQuery.of(context).size.width <= 768)
                GestureDetector(
                  onTap: onMenuPressed,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.menu,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _NavItem({
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
