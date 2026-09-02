import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import 'dev_log.dart';

/// Painel do modo dev (SÓ em builds de debug — [kDebugMode] guarda todos os
/// pontos de entrada; nada disto existe em release).
///
/// - Login de 1 toque com a conta de teste (`--dart-define=DEV_EMAIL/DEV_SENHA`
///   ou o último e-mail/senha digitados aqui, lembrados em SharedPreferences);
/// - atalho de modo visitante;
/// - console de logs/erros do app ([DevLog]) com copiar/limpar.
///
/// "Impersonar" um usuário arbitrário não é possível no app: os dados vêm
/// direto do Supabase sob RLS (own-only) — o `X-Dev-Impersonate` do site só
/// vale para as rotas do Express. O equivalente prático é logar com contas
/// de teste reais.
Future<void> mostrarDevPanel(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const DevPanel(),
  );
}

/// Abre direto o console de logs (usado pelo botão flutuante do shell).
Future<void> mostrarDevLogs(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const DevLogViewer(),
  );
}

/// Conta de teste pré-definida do painel (aluno/admin).
class ContaDev {
  final String rotulo;
  final IconData icone;
  final String email;
  final String senha;

  const ContaDev({
    required this.rotulo,
    required this.icone,
    required this.email,
    required this.senha,
  });

  bool get valida => email.isNotEmpty && senha.isNotEmpty;
}

/// Contas vindas do `dev.env.json` (--dart-define-from-file); só as
/// preenchidas aparecem no painel.
const List<ContaDev> kContasDevPadrao = [
  ContaDev(
    rotulo: 'Entrar como Aluno',
    icone: Icons.school_outlined,
    email: AppConfig.devAlunoEmail,
    senha: AppConfig.devAlunoSenha,
  ),
  ContaDev(
    rotulo: 'Entrar como Admin',
    icone: Icons.admin_panel_settings_outlined,
    email: AppConfig.devAdminEmail,
    senha: AppConfig.devAdminSenha,
  ),
];

class DevPanel extends ConsumerStatefulWidget {
  /// Injetável nos testes (o default vem dos dart-defines).
  final List<ContaDev> contas;

  const DevPanel({super.key, this.contas = kContasDevPadrao});

  @override
  ConsumerState<DevPanel> createState() => _DevPanelState();
}

class _DevPanelState extends ConsumerState<DevPanel> {
  static const _kPrefEmail = 'dev_panel_email';
  static const _kPrefSenha = 'dev_panel_senha';

  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _entrando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregarLembrados();
  }

  Future<void> _carregarLembrados() async {
    if (_emailController.text.isNotEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _emailController.text = prefs.getString(_kPrefEmail) ?? '';
      _senhaController.text = prefs.getString(_kPrefSenha) ?? '';
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  /// Núcleo do login do painel; [lembrar] guarda as credenciais digitadas
  /// (as contas pré-definidas vêm do dev.env.json, não precisam).
  Future<void> _login(
    String email,
    String senha, {
    bool lembrar = false,
  }) async {
    setState(() {
      _entrando = true;
      _erro = null;
    });
    if (lembrar) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefEmail, email);
      await prefs.setString(_kPrefSenha, senha);
    }

    final erro = await ref
        .read(authProvider.notifier)
        .loginComEmail(email, senha);
    if (!mounted) return;
    if (erro != null) {
      DevLog.registrar('DevPanel: login falhou — $erro');
      setState(() {
        _entrando = false;
        _erro = erro;
      });
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _entrar() async {
    final email = _emailController.text.trim();
    final senha = _senhaController.text;
    if (email.isEmpty || senha.isEmpty) {
      setState(() => _erro = 'Preencha e-mail e senha da conta de teste.');
      return;
    }
    await _login(email, senha, lembrar: true);
  }

  Future<void> _visitante() async {
    await ref.read(authProvider.notifier).entrarComoVisitante();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.build_outlined,
                size: 18,
                color: AppColors.accent,
              ),
              const SizedBox(width: 8),
              Text('Modo dev', style: tema.titleMedium),
              const Spacer(),
              Text(
                'só em debug',
                style: tema.labelSmall?.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Contas pré-definidas (dev.env.json): 1 toque, sem digitar nada.
          for (final conta in widget.contas.where((c) => c.valida)) ...[
            FilledButton.icon(
              onPressed: _entrando
                  ? null
                  : () => _login(conta.email, conta.senha),
              icon: Icon(conta.icone, size: 18),
              label: Text(conta.rotulo),
            ),
            const SizedBox(height: 8),
          ],
          if (widget.contas.any((c) => c.valida)) const Divider(height: 24),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'E-mail da conta de teste',
              prefixIcon: Icon(Icons.alternate_email, size: 18),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _senhaController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Senha',
              prefixIcon: Icon(Icons.key_outlined, size: 18),
            ),
          ),
          if (_erro != null) ...[
            const SizedBox(height: 10),
            Text(_erro!, style: const TextStyle(color: AppColors.destructive)),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _entrando ? null : _entrar,
            icon: _entrando
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.flash_on, size: 18),
            label: const Text('Entrar com a conta de teste'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _entrando ? null : _visitante,
            icon: const Icon(Icons.person_off_outlined, size: 18),
            label: const Text('Entrar como visitante'),
          ),
          const Divider(height: 28),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              mostrarDevLogs(context);
            },
            icon: const Icon(Icons.terminal, size: 18),
            label: const Text('Ver logs e erros do app'),
          ),
        ],
      ),
    );
  }
}

/// Console de logs: lista o buffer do [DevLog] com copiar/limpar.
class DevLogViewer extends StatelessWidget {
  const DevLogViewer({super.key});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
            child: Row(
              children: [
                const Icon(Icons.terminal, size: 18, color: AppColors.accent),
                const SizedBox(width: 8),
                Text(
                  'Logs do app',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Copiar tudo',
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: DevLog.textoCompleto),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                        const SnackBar(content: Text('Logs copiados')),
                      );
                    }
                  },
                ),
                IconButton(
                  tooltip: 'Limpar',
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: DevLog.limpar,
                ),
              ],
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<List<String>>(
              valueListenable: DevLog.linhas,
              builder: (context, linhas, _) {
                if (linhas.isEmpty) {
                  return const Center(
                    child: Text(
                      'Nenhum log ainda.\nErros e debugPrints aparecem aqui.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.mutedForeground),
                    ),
                  );
                }
                return ListView.builder(
                  controller: scrollController,
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: linhas.length,
                  itemBuilder: (context, i) {
                    final linha = linhas[linhas.length - 1 - i];
                    final ehErro =
                        linha.contains('ERROR') || linha.contains('falhou');
                    return SelectableText(
                      linha,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        height: 1.5,
                        color: ehErro
                            ? AppColors.destructive
                            : AppColors.foreground,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
