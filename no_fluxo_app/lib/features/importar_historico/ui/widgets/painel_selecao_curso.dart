import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/casamento.dart';
import '../../domain/validacao_arquivo.dart';

/// Painel de seleção de curso — porte do CourseSelectionModal do site:
/// mensagem, busca sem acentos, lista com radio e Cancelar/Confirmar.
///
/// Usado tanto no COURSE_SELECTION da RPC quanto no modo manual.
class PainelSelecaoCurso extends StatefulWidget {
  final String mensagem;
  final List<OpcaoCurso> cursos;
  final ValueChanged<OpcaoCurso> onConfirmar;
  final VoidCallback onCancelar;

  const PainelSelecaoCurso({
    super.key,
    required this.mensagem,
    required this.cursos,
    required this.onConfirmar,
    required this.onCancelar,
  });

  @override
  State<PainelSelecaoCurso> createState() => _PainelSelecaoCursoState();
}

class _PainelSelecaoCursoState extends State<PainelSelecaoCurso> {
  String _busca = '';
  OpcaoCurso? _selecionado;

  List<OpcaoCurso> get _filtrados {
    final termo = removerAcentos(_busca.trim()).toLowerCase();
    if (termo.isEmpty) return widget.cursos;
    return [
      for (final curso in widget.cursos)
        if (removerAcentos(curso.nomeCurso).toLowerCase().contains(termo))
          curso,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final filtrados = _filtrados;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Selecionar Curso',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          widget.mensagem.isNotEmpty
              ? widget.mensagem
              : 'Encontramos mais de um curso possível. Selecione o correto:',
          style: textTheme.bodySmall?.copyWith(
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: (valor) => setState(() => _busca = valor),
          decoration: const InputDecoration(
            hintText: 'Pesquisar curso...',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 8),
        // Altura limitada para funcionar tanto no bottom sheet quanto
        // inline dentro do scroll da tela (contexto de altura ilimitada).
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: filtrados.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Nenhum curso encontrado.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: filtrados.length,
                  itemBuilder: (context, index) {
                    final curso = filtrados[index];
                    final ativo = identical(_selecionado, curso);
                    final detalhe = curso.detalhe;
                    return ListTile(
                      dense: true,
                      onTap: () => setState(() => _selecionado = curso),
                      selected: ativo,
                      selectedColor: AppColors.foreground,
                      leading: Icon(
                        ativo
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        size: 20,
                        color: ativo
                            ? AppColors.primary
                            : AppColors.mutedForeground,
                      ),
                      title: Text(curso.nomeCurso),
                      subtitle: detalhe.isEmpty ? null : Text(detalhe),
                    );
                  },
                ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: widget.onCancelar,
                child: const Text('Cancelar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _selecionado == null
                    ? null
                    : () => widget.onConfirmar(_selecionado!),
                child: const Text('Confirmar'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
