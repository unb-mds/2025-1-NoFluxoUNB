import 'package:flutter/material.dart';
import '../../widgets/app_navbar.dart';
import '../../widgets/graffiti_background.dart';

class FluxogramasIndexScreen extends StatelessWidget {
  const FluxogramasIndexScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const GraffitiBackground(),
          SafeArea(
            child: Column(
              children: const [
                AppNavbar(),
                // Conteúdo da página de fluxogramas será adicionado aqui
              ],
            ),
          ),
        ],
      ),
    );
  }
} 