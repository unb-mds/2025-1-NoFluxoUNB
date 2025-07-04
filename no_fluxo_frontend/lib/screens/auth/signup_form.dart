import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/service/auth_service.dart';
import '../../constants/app_colors.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:brasil_fields/brasil_fields.dart';

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
  final _authService = AuthService();
  bool _acceptTerms = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _emailError;
  String? _termsError;
  bool _isLoading = false;

  // Validation states
  bool _isNameValid = false;
  bool _isEmailValid = false;
  bool _isPasswordValid = false;
  bool _isConfirmPasswordValid = false;

  // Password requirements
  final _minLength = 8;
  final _hasUpperCase = RegExp(r'[A-Z]');
  final _hasLowerCase = RegExp(r'[a-z]');
  final _hasNumbers = RegExp(r'[0-9]');
  final _hasSpecialCharacters = RegExp(r'[!@#\$&*~]');
  final _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  @override
  void initState() {
    super.initState();
    // Add listeners to all controllers
    _nameController.addListener(_validateForm);
    _emailController.addListener(_validateForm);
    _passwordController.addListener(_validateForm);
    _confirmPasswordController.addListener(_validateForm);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _validateForm() {
    setState(() {
      // Validate name
      _isNameValid = _nameController.text.trim().split(' ').length >= 2 &&
          _nameController.text.trim().length >= 3;

      // Validate email
      _isEmailValid = _emailRegex.hasMatch(_emailController.text.trim());

      // Validate password
      final password = _passwordController.text;
      _isPasswordValid = password.length >= _minLength &&
          _hasUpperCase.hasMatch(password) &&
          _hasLowerCase.hasMatch(password) &&
          _hasNumbers.hasMatch(password) &&
          _hasSpecialCharacters.hasMatch(password);

      // Validate confirm password
      _isConfirmPasswordValid =
          _confirmPasswordController.text == _passwordController.text &&
              _confirmPasswordController.text.isNotEmpty;
    });
  }

  bool get _isFormValid =>
      _isNameValid &&
      _isEmailValid &&
      _isPasswordValid &&
      _isConfirmPasswordValid &&
      _acceptTerms;

  List<String> get _missingRequirements {
    final missing = <String>[];
    if (!_isNameValid) missing.add('Nome completo válido');
    if (!_isEmailValid) missing.add('Email válido');
    if (!_isPasswordValid) missing.add('Senha que atenda aos requisitos');
    if (!_isConfirmPasswordValid) missing.add('Confirmação de senha');
    if (!_acceptTerms) missing.add('Aceitar os termos');
    return missing;
  }

  // Password strength indicators
  Widget _buildPasswordStrengthIndicator(String requirement, bool isMet) {
    return Row(
      children: [
        Icon(
          isMet ? Icons.check_circle : Icons.cancel,
          color: isMet ? Colors.green : Colors.grey,
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          requirement,
          style: GoogleFonts.poppins(
            color: isMet ? Colors.green : Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // Função para criar conta com email/senha
  Future<void> _signUpWithEmail() async {
    // Validações básicas
    final valid = _formKey.currentState!.validate();
    if (!valid) {
      _handleEmailValidationError();
      return;
    }

    if (!_acceptTerms) {
      setState(() {
        _termsError =
            'Você deve concordar com os Termos de Serviço e Política de Privacidade para continuar.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _emailError = null;
      _termsError = null;
    });

    try {
      // Chama o AuthService para criar conta
      final user = await _authService.signUpWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: _nameController.text.trim(),
      );

      if (user != null) {
        // Sucesso - navega para próxima tela
        if (mounted) {
          context.go('/upload-historico');
        }
      } else {
        // Falha na criação da conta
        setState(() {
          _emailError = 'Erro ao criar conta. Tente novamente.';
        });
      }
    } catch (e) {
      // Trata erros específicos
      setState(() {
        _emailError = _getErrorMessage(e.toString());
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Função para login com Google
  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _emailError = null;
      _termsError = null;
    });

    try {
      final user = await _authService.signInWithGoogle();

      user.fold((l) {
        setState(() {
          _emailError = "Erro ao fazer login com Google. Tente novamente.\n$l";
        });
      }, (r) {
        print("User: $r");
        if (mounted) {
          //context.go('/upload-historico');
        }
      });
    } catch (e) {
      setState(() {
        _emailError = _getErrorMessage(e.toString());
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Função auxiliar para tratar erros de validação de email
  void _handleEmailValidationError() {
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
      } else if (!parts[1].contains('.') ||
          parts[1].startsWith('.') ||
          parts[1].endsWith('.')) {
        setState(() {
          _emailError = 'Inclua um domínio válido após o "@" (ex: gmail.com).';
        });
      } else {
        setState(() {
          _emailError = 'E-mail inválido.';
        });
      }
    }
  }

  // Função para converter erros em mensagens amigáveis
  String _getErrorMessage(String error) {
    if (error.contains('email-already-in-use')) {
      return 'Este e-mail já está em uso. Tente fazer login ou use outro e-mail.';
    } else if (error.contains('weak-password')) {
      return 'A senha é muito fraca. Use pelo menos 8 caracteres.';
    } else if (error.contains('invalid-email')) {
      return 'E-mail inválido. Verifique se está correto.';
    } else if (error.contains('network-request-failed')) {
      return 'Erro de conexão. Verifique sua internet e tente novamente.';
    }
    return 'Erro inesperado. Tente novamente em alguns instantes.';
  }

  @override
  Widget build(BuildContext context) {
    final password = _passwordController.text;

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
                if (_emailError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4E5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFFB020)),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: Color(0xFFFFB020), size: 28),
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
                if (_termsError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4E5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFFB020)),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: Color(0xFFFFB020), size: 28),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _termsError!,
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
                  enabled: !_isLoading,
                  decoration: InputDecoration(
                    hintText: 'Nome completo',
                    errorText: _nameController.text.isNotEmpty && !_isNameValid
                        ? 'Insira nome e sobrenome'
                        : null,
                    hintStyle: GoogleFonts.poppins(color: Colors.grey[600]),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 18),
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
                  style:
                      GoogleFonts.poppins(color: Colors.black87, fontSize: 16),
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
                  enabled: !_isLoading,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'E-mail',
                    errorText:
                        _emailController.text.isNotEmpty && !_isEmailValid
                            ? 'Email inválido'
                            : null,
                    hintStyle: GoogleFonts.poppins(color: Colors.grey[600]),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 18),
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
                  style:
                      GoogleFonts.poppins(color: Colors.black87, fontSize: 16),
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
                    if (!parts[1].contains('.') ||
                        parts[1].startsWith('.') ||
                        parts[1].endsWith('.')) {
                      return 'Inclua um domínio válido após o "@" (ex: gmail.com).';
                    }
                    if (!_emailRegex.hasMatch(value)) {
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
                  enabled: !_isLoading,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'Senha',
                    errorText:
                        _passwordController.text.isNotEmpty && !_isPasswordValid
                            ? 'Senha não atende aos requisitos'
                            : null,
                    hintStyle: GoogleFonts.poppins(color: Colors.grey[600]),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 18),
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
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: Colors.grey[600],
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  style:
                      GoogleFonts.poppins(color: Colors.black87, fontSize: 16),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, insira sua senha';
                    }
                    if (value.length < 8) {
                      return 'A senha deve ter pelo menos 8 caracteres';
                    }
                    return null;
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPasswordStrengthIndicator(
                        'Mínimo de $_minLength caracteres',
                        password.length >= _minLength,
                      ),
                      _buildPasswordStrengthIndicator(
                        'Letra maiúscula',
                        _hasUpperCase.hasMatch(password),
                      ),
                      _buildPasswordStrengthIndicator(
                        'Letra minúscula',
                        _hasLowerCase.hasMatch(password),
                      ),
                      _buildPasswordStrengthIndicator(
                        'Número',
                        _hasNumbers.hasMatch(password),
                      ),
                      _buildPasswordStrengthIndicator(
                        'Caractere especial (!@#\$&*~)',
                        _hasSpecialCharacters.hasMatch(password),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  enabled: !_isLoading,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    hintText: 'Confirmar senha',
                    errorText: _confirmPasswordController.text.isNotEmpty &&
                            !_isConfirmPasswordValid
                        ? 'As senhas não coincidem'
                        : null,
                    hintStyle: GoogleFonts.poppins(color: Colors.grey[600]),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 18),
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
                        _obscureConfirmPassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: Colors.grey[600],
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                  ),
                  style:
                      GoogleFonts.poppins(color: Colors.black87, fontSize: 16),
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
                      onChanged: _isLoading
                          ? null
                          : (value) {
                              setState(() {
                                _acceptTerms = value ?? false;
                                if (_termsError != null) {
                                  _termsError = null;
                                }
                              });
                            },
                      activeColor: const Color(0xFF2563EB),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                    ),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.poppins(
                              fontSize: 13, color: Colors.grey[700]),
                          children: [
                            const TextSpan(text: 'Eu concordo com os '),
                            TextSpan(
                              text: 'Termos de Serviço',
                              style: const TextStyle(
                                  color: Color(0xFF6366F1),
                                  decoration: TextDecoration.underline),
                            ),
                            const TextSpan(text: ' e '),
                            TextSpan(
                              text: 'Política de Privacidade',
                              style: const TextStyle(
                                  color: Color(0xFF6366F1),
                                  decoration: TextDecoration.underline),
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
                    onPressed:
                        _isFormValid && !_isLoading ? _signUpWithEmail : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[300],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Criar conta'),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(
                        child: Divider(thickness: 1, color: Color(0xFFD1D5DB))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'ou',
                        style: GoogleFonts.poppins(
                            color: Colors.grey[600], fontSize: 15),
                      ),
                    ),
                    const Expanded(
                        child: Divider(thickness: 1, color: Color(0xFFD1D5DB))),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    icon: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.grey,
                            ),
                          )
                        : SvgPicture.asset(
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
                      disabledBackgroundColor: Colors.grey[50],
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          vertical: 0, horizontal: 8),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: TextButton(
                    onPressed: _isLoading ? null : widget.onToggleView,
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
                if (_missingRequirements.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Falta preencher:',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          ...(_missingRequirements.map((req) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 2.0),
                                child: Row(
                                  children: [
                                    Icon(Icons.error_outline,
                                        size: 16, color: Colors.grey[600]),
                                    const SizedBox(width: 8),
                                    Text(
                                      req,
                                      style: GoogleFonts.poppins(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ))),
                        ],
                      ),
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
