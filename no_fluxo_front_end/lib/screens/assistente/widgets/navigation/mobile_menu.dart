import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MobileMenu extends StatelessWidget {
  final VoidCallback onClose;

  const MobileMenu({
    Key? key,
    required this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Backdrop
        Positioned.fill(
          child: GestureDetector(
            onTap: onClose,
            child: Container(
              color: Colors.black.withOpacity(0.5),
            ),
          ),
        ),

        // Menu Content
        Positioned(
          top: 0,
          right: 0,
          bottom: 0,
          width: MediaQuery.of(context).size.width * 0.75,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.95),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(-5, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                // Close Button
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: onClose,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Navigation Items
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _MobileNavItem(
                          title: 'HOME',
                          onTap: () {
                            onClose();
                            context.go('/');
                          },
                        ),
                        const SizedBox(height: 24),
                        _MobileNavItem(
                          title: 'FLUXOGRAMAS',
                          onTap: () {
                            onClose();
                            context.go('/fluxogramas');
                          },
                        ),
                        const SizedBox(height: 24),
                        _MobileNavItem(
                          title: 'SOBRE NÓS',
                          onTap: () {
                            onClose();
                            context.go('/#sobre');
                          },
                        ),
                        const SizedBox(height: 24),
                        _MobileNavItem(
                          title: 'ASSISTENTE',
                          onTap: () {
                            onClose();
                            context.go('/assistente');
                          },
                        ),
                      ],
                    ),
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

class _MobileNavItem extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _MobileNavItem({
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
