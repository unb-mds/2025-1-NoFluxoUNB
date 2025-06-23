import 'package:flutter/material.dart';
import '../../widgets/animated_background.dart';

class AssistenteScreen extends StatefulWidget {
  const AssistenteScreen({Key? key}) : super(key: key);

  @override
  State<AssistenteScreen> createState() => _AssistenteScreenState();
}

class _AssistenteScreenState extends State<AssistenteScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          const AnimatedBackground(),

          // Main Content
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'ASSISTENTE NOFLUXO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Página do Assistente Funcionando!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: () {
                      print('🟢 Botão clicado na página do assistente!');
                    },
                    child: const Text('Teste'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
