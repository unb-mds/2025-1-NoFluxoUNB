import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SignupForm extends StatefulWidget {
  final VoidCallback onToggleView;

  const SignupForm({
    super.key,
    required this.onToggleView,
  });

  @override
  State<SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends State<SignupForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _acceptTerms = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
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
                Text(
                  'Criar Conta',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: 'Nome completo',
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
                      return 'Por favor, insira seu nome';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
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
                      return 'Por favor, insira seu email';
                    }
                    return null;
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
                Padding(
                  padding: const EdgeInsets.only(top: 4.0, left: 2.0),
                  child: Text(
                    'A senha deve ter pelo menos 8 caracteres',
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500]),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    hintText: 'Confirmar senha',
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
                        _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                        color: Colors.grey[600],
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                  ),
                  style: GoogleFonts.poppins(color: Colors.black87, fontSize: 16),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, confirme sua senha';
                    }
                    if (value != _passwordController.text) {
                      return 'As senhas não coincidem';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _acceptTerms,
                      onChanged: (value) {
                        setState(() {
                          _acceptTerms = value ?? false;
                        });
                      },
                      activeColor: const Color(0xFF2563EB),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]),
                          children: [
                            const TextSpan(text: 'Eu concordo com os '),
                            TextSpan(
                              text: 'Termos de Serviço',
                              style: const TextStyle(color: Color(0xFF6366F1), decoration: TextDecoration.underline),
                              // onEnter/onTap pode ser adicionado para navegação
                            ),
                            const TextSpan(text: ' e '),
                            TextSpan(
                              text: 'Política de Privacidade',
                              style: const TextStyle(color: Color(0xFF6366F1), decoration: TextDecoration.underline),
                            ),
                          ],
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
                      if (_formKey.currentState!.validate() && _acceptTerms) {
                        context.go('/auth/upload');
                      }
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
                    child: const Text('Criar conta'),
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
                    onPressed: () {},
                    icon: SvgPicture.asset(
                      'assets/icons/Google__G__logo.svg',
                      height: 24,
                      width: 24,
                    ),
                    label: Text(
                      'Cadastrar com o Google',
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
                    child: const Text('Já tem uma conta? Faça login'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
