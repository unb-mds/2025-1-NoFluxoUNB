import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dev/dev_panel.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';

/// Tela de login: email/senha, modo visitante, Google e link para signup.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _carregando = false;
  bool _senhaVisivel = false;

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  void _mostrarErro(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: AppColors.destructive.withValues(alpha: 0.9),
      ),
    );
  }

  Future<void> _entrar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _carregando = true);
    final erro = await ref
        .read(authProvider.notifier)
        .loginComEmail(_emailController.text, _senhaController.text);
    if (!mounted) return;
    setState(() => _carregando = false);
    if (erro != null) _mostrarErro(erro);
    // Sucesso: o redirect do router leva para o app.
  }

  Future<void> _entrarComoVisitante() async {
    await ref.read(authProvider.notifier).entrarComoVisitante();
  }

  Future<void> _entrarComGoogle() async {
    final erro = await ref.read(authProvider.notifier).loginComGoogle();
    if (erro != null) _mostrarErro(erro);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Modo dev: atalho discreto, só existe em builds de debug.
                    if (kDebugMode)
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          tooltip: 'Modo dev',
                          icon: const Icon(
                            Icons.build_outlined,
                            size: 18,
                            color: AppColors.mutedForeground,
                          ),
                          onPressed: () => mostrarDevPanel(context),
                        ),
                      ),
                    Text('NoFluxo', style: textTheme.headlineLarge),
                    const SizedBox(height: 4),
                    Text(
                      'Seu fluxograma da UnB, sem fluxo.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        hintText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                      validator: (v) {
                        final email = v?.trim() ?? '';
                        if (email.isEmpty) return 'Informe seu email';
                        if (!email.contains('@')) return 'Email inválido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _senhaController,
                      obscureText: !_senhaVisivel,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _entrar(),
                      decoration: InputDecoration(
                        hintText: 'Senha',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _senhaVisivel
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () =>
                              setState(() => _senhaVisivel = !_senhaVisivel),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Informe sua senha' : null,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _carregando ? null : _entrar,
                      child: _carregando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Entrar'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _carregando ? null : _entrarComGoogle,
                      icon: Image.asset(
                        'assets/images/google_logo.png',
                        width: 20,
                        height: 20,
                      ),
                      label: const Text('Entrar com Google'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _carregando ? null : _entrarComoVisitante,
                      child: const Text('Continuar como visitante'),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Não tem conta?',
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.go('/signup'),
                          child: const Text('Criar conta'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
