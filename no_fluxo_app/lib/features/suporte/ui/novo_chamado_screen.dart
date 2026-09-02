import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../data/suporte_repository.dart';
import '../data/ticket_model.dart';

/// Formulário de novo chamado: categoria (SegmentedButton), título e
/// descrição obrigatórios, envio com loading. Em sucesso faz pop(true) — a
/// [SuporteScreen] recarrega a lista e mostra o snackbar.
class NovoChamadoScreen extends ConsumerStatefulWidget {
  const NovoChamadoScreen({super.key});

  @override
  ConsumerState<NovoChamadoScreen> createState() => _NovoChamadoScreenState();
}

class _NovoChamadoScreenState extends ConsumerState<NovoChamadoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descricaoController = TextEditingController();
  TicketCategoria _categoria = TicketCategoria.bug;
  bool _enviando = false;

  @override
  void dispose() {
    _tituloController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_enviando || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _enviando = true);
    try {
      await ref
          .read(suporteRepositoryProvider)
          .criarTicket(
            title: _tituloController.text,
            description: _descricaoController.text,
            categoria: _categoria,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _enviando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível enviar seu chamado. Tente novamente.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Novo chamado')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Text(
                'Qual o tipo do chamado?',
                style: tema.labelLarge?.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<TicketCategoria>(
                segments: [
                  for (final c in TicketCategoria.values)
                    ButtonSegment(value: c, label: Text(c.label)),
                ],
                selected: {_categoria},
                onSelectionChanged: _enviando
                    ? null
                    : (sel) => setState(() => _categoria = sel.first),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _tituloController,
                enabled: !_enviando,
                textInputAction: TextInputAction.next,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  hintText: 'Resumo em uma frase',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Dê um título ao chamado'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descricaoController,
                enabled: !_enviando,
                minLines: 5,
                maxLines: 10,
                decoration: const InputDecoration(
                  labelText: 'Descrição',
                  hintText:
                      'Descreva o que aconteceu ou sua ideia com o máximo '
                      'de detalhes',
                  alignLabelWithHint: true,
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Descreva o chamado'
                    : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _enviando ? null : _enviar,
                icon: _enviando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined, size: 18),
                label: Text(_enviando ? 'Enviando…' : 'Enviar chamado'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
