import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import 'password_recovery_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'anonymous_login_screen.dart';
import 'package:email_validator/email_validator.dart';
import 'dart:async';

class LoginForm extends StatefulWidget {
  final VoidCallback onToggleView;

  const LoginForm({
    super.key,
    required this.onToggleView,
  });

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _obscurePassword = true;
  String? _emailError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_emailError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4E5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFFB020)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Color(0xFFFFB020), size: 28),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _emailError!,
                              style: GoogleFonts.poppins(
                                color: Colors.black87,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Text(
                  'Login',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'E-mail',
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
                      return 'Por favor, insira seu e-mail';
                    }
                    if (!value.contains('@')) {
                      return 'Inclua um "@" no endereço de e-mail.';
                    }
                    final parts = value.split('@');
                    if (parts.length != 2 || parts[1].isEmpty) {
                      return 'Inclua um domínio após o "@" (ex: gmail.com).';
                    }
                    if (!parts[1].contains('.') || parts[1].startsWith('.') || parts[1].endsWith('.')) {
                      return 'Inclua um domínio válido após o "@" (ex: gmail.com).';
                    }
                    if (!EmailValidator.validate(value)) {
                      return 'E-mail inválido.';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    if (_emailError != null) {
                      setState(() {
                        _emailError = null;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'Senha',
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
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility : Icons.visibility_off,
                        color: Colors.grey[600],
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  style: GoogleFonts.poppins(color: Colors.black87, fontSize: 16),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, insira sua senha';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      onChanged: (value) {
                        setState(() {
                          _rememberMe = value ?? false;
                        });
                      },
                      activeColor: const Color(0xFF2563EB),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    Text(
                      'Lembrar-me',
                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[700]),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PasswordRecoveryScreen(),
                          ),
                        );
                      },
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Text(
                          'Esqueceu a senha?',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: const Color(0xFF6366F1),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      final valid = _formKey.currentState!.validate();
                      if (!valid) {
                        final email = _emailController.text;
                        if (email.isEmpty) {
                          setState(() {
                            _emailError = 'Por favor, insira seu e-mail';
                          });
                        } else if (!email.contains('@')) {
                          setState(() {
                            _emailError = 'Inclua um "@" no endereço de e-mail.';
                          });
                        } else {
                          final parts = email.split('@');
                          if (parts.length != 2 || parts[1].isEmpty) {
                            setState(() {
                              _emailError = 'Inclua um domínio após o "@" (ex: gmail.com).';
                            });
                          } else if (!parts[1].contains('.') || parts[1].startsWith('.') || parts[1].endsWith('.')) {
                            setState(() {
                              _emailError = 'Inclua um domínio válido após o "@" (ex: gmail.com).';
                            });
                          } else {
                            setState(() {
                              _emailError = 'E-mail inválido.';
                            });
                          }
                        }
                        return;
                      }
                      setState(() {
                        _emailError = null;
                      });
                      _showLoginSuccessModal(context, 'email');
                    },
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
                    child: const Text('Entrar'),
                  ),
                ),
                const SizedBox(height: 18),
                // Separador "ou"
                Row(
                  children: [
                    const Expanded(child: Divider(thickness: 1, color: Color(0xFFD1D5DB))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'ou',
                        style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 15),
                      ),
                    ),
                    const Expanded(child: Divider(thickness: 1, color: Color(0xFFD1D5DB))),
                  ],
                ),
                const SizedBox(height: 18),
                // Botão Google
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _showLoginSuccessModal(context, 'google');
                    },
                    icon: SvgPicture.asset(
                      'assets/icons/Google__G__logo.svg',
                      height: 24,
                      width: 24,
                    ),
                    label: Text(
                      'Entrar com o Google',
                      style: GoogleFonts.poppins(
                        color: Colors.grey[800],
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // Botão Visitante
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AnonymousLoginScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                      ),
                      elevation: 1,
                    ),
                    child: const Text('Entrar como Visitante'),
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: TextButton(
                    onPressed: widget.onToggleView,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.black87,
                      textStyle: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    child: const Text('Não tem uma conta? Cadastre-se'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLoginSuccessModal(BuildContext context, String loginType) {
    bool closed = false;
    late Timer timer;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
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
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6FAF0),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Icon(Icons.check, color: Colors.green[600], size: 32),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Login realizado',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    loginType == 'google'
                        ? 'Você entrou com o Google.'
                        : 'Você entrou com e-mail.',
                    style: GoogleFonts.poppins(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () {
                        closed = true;
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF183C8B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('OK'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    timer = Timer(const Duration(seconds: 2), () {
      if (context.mounted) {
        if (!closed) {
          closed = true;
          Navigator.of(context).pop();
        }
        context.go('/auth/upload');
      }
    });
  }
}
