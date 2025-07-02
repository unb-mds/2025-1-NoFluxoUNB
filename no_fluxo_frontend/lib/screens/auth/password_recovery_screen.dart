import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../widgets/animated_background.dart';
import '../../widgets/app_navbar.dart';

class PasswordRecoveryScreen extends StatefulWidget {
  const PasswordRecoveryScreen({super.key});

  @override
  State<PasswordRecoveryScreen> createState() => _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _sendRecoveryEmail() {
    if (_formKey.currentState!.validate()) {
      // TODO: Implementar envio de e-mail de recuperação
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Enviando e-mail de recuperação para ${_emailController.text}...'),
        ),
      );
      // Navegar de volta ou mostrar mensagem de sucesso
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const AnimatedBackground(),
          SafeArea(
            child: Column(
              children: [
                const AppNavbar(),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 18),
                              Text(
                                'Recuperar Senha',
                                style: GoogleFonts.poppins(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Digite seu e-mail para receber um link de recuperação',
                                style: GoogleFonts.poppins(
                                  color: Colors.grey[600],
                                  fontSize: 15,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              Form(
                                key: _formKey,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    TextFormField(
                                      controller: _emailController,
                                      decoration: InputDecoration(
                                        hintText: 'Seu e-mail',
                                        hintStyle: GoogleFonts.poppins(color: Colors.grey[600]),
                                        filled: true,
                                        fillColor: Colors.white,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(14),
                                          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(14),
                                          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(14),
                                          borderSide: const BorderSide(color: Color(0xFF2563EB)),
                                        ),
                                      ),
                                      style: GoogleFonts.poppins(color: Colors.black87, fontSize: 16),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Por favor, insira seu email';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 22),
                                    SizedBox(
                                      height: 52,
                                      child: ElevatedButton(
                                        onPressed: _sendRecoveryEmail,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF2563EB),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          textStyle: GoogleFonts.poppins(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          elevation: 2,
                                        ),
                                        child: const Text('Enviar link de recuperação'),
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    Center(
                                      child: TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                        },
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.black87,
                                          textStyle: GoogleFonts.poppins(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                        child: const Text('Voltar para o login'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 