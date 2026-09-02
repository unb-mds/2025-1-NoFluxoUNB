import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/turma_model.dart';
import '../../../core/services/auth_service.dart' show estaLogadoProvider;
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/busca.dart';
import '../../../core/utils/horario_slots.dart';
import '../../../core/widgets/vagas_badge.dart';
import '../data/grade_repository.dart';

/// Bottom sheet do "+ turma": busca a matéria por código/nome e lista as
/// turmas ofertadas no período ativo. Devolve o [TurmaModel] escolhido via
/// `Navigator.pop` — quem adiciona à grade é a tela.
class AdicionarTurmaSheet extends ConsumerStatefulWidget {
  const AdicionarTurmaSheet({super.key});

  @override
  ConsumerState<AdicionarTurmaSheet> createState() =>
      _AdicionarTurmaSheetState();
}

class _AdicionarTurmaSheetState extends ConsumerState<AdicionarTurmaSheet> {
  Timer? _debounce;
  bool _buscando = false;
  String? _erro;
  String _query = '';
  List<MateriaBusca> _materias = const [];

  MateriaBusca? _materiaSelecionada;
  bool _carregandoTurmas = false;
  List<TurmaModel> _turmas = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _buscar(query);
    });
  }

  /// Geração da busca em voo: uma resposta lenta de busca antiga não pode
  /// sobrescrever o resultado da busca mais recente.
  int _geracaoBusca = 0;

  Future<void> _buscar(String query) async {
    if (!mounted) return;
    final geracao = ++_geracaoBusca;
    setState(() {
      _buscando = true;
      _erro = null;
      _query = query;
      _materiaSelecionada = null;
      _turmas = const [];
    });
    try {
      final materias = await ref
          .read(gradeRepositoryProvider)
          .buscarMaterias(query);
      if (!mounted || geracao != _geracaoBusca) return;
      setState(() {
        _materias = materias;
        _buscando = false;
      });
    } catch (e) {
      if (!mounted || geracao != _geracaoBusca) return;
      setState(() {
        _erro = 'Não foi possível buscar. Verifique sua conexão.';
        _buscando = false;
      });
    }
  }

  Future<void> _selecionarMateria(MateriaBusca materia) async {
    setState(() {
      _materiaSelecionada = materia;
      _carregandoTurmas = true;
      _turmas = const [];
      _erro = null;
    });
    try {
      final turmas = await ref
          .read(gradeRepositoryProvider)
          .turmasDaMateria(materia.idMateria);
      if (!mounted) return;
      setState(() {
        _turmas = turmas;
        _carregandoTurmas = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = 'Não foi possível carregar as turmas.';
        _carregandoTurmas = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        // Sobe junto com o teclado.
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Adicionar turma',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              autofocus: true,
              onChanged: _onQueryChanged,
              decoration: const InputDecoration(
                hintText: 'Buscar matéria (código ou nome)',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 12),
            if (_erro != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _erro!,
                  style: const TextStyle(color: AppColors.destructive),
                ),
              ),
            Flexible(
              child: _buscando || _carregandoTurmas
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _materiaSelecionada == null
                  ? _listaMaterias()
                  : _listaTurmas(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listaMaterias() {
    if (_materias.isEmpty) {
      // Visitante que buscou de verdade recebe do RLS lista vazia SEM erro —
      // o empty-state genérico seria mentira confusa (mesmo tratamento da
      // tela de Turmas).
      final buscou = sanitizarTermoBusca(_query).length >= kMinCaracteresBusca;
      if (buscou && !ref.watch(estaLogadoProvider)) {
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline,
                size: 32,
                color: AppColors.mutedForeground,
              ),
              SizedBox(height: 8),
              Text(
                'Entre com sua conta para buscar turmas — o acesso sem '
                'login ainda não está liberado.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.mutedForeground),
              ),
            ],
          ),
        );
      }
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Digite ao menos 2 caracteres para buscar.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.mutedForeground),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      itemCount: _materias.length,
      itemBuilder: (context, i) {
        final m = _materias[i];
        return ListTile(
          title: Text(
            m.codigo,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
          subtitle: Text(m.nome),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: () => _selecionarMateria(m),
        );
      },
    );
  }

  Widget _listaTurmas() {
    final materia = _materiaSelecionada!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 20),
              onPressed: () => setState(() => _materiaSelecionada = null),
            ),
            Expanded(
              child: Text(
                '${materia.codigo} — ${materia.nome}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        Flexible(
          child: _turmas.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Nenhuma turma ofertada neste período.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.mutedForeground),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _turmas.length,
                  itemBuilder: (context, i) {
                    final t = _turmas[i];
                    final horario = describeHorario(t.horario);
                    final detalhes = [
                      if (horario.isNotEmpty) horario else 'Horário a definir',
                      if ((t.docente ?? '').trim().isNotEmpty)
                        t.docente!.trim(),
                      if ((t.local ?? '').trim().isNotEmpty) t.local!.trim(),
                    ].join('\n');
                    return ListTile(
                      title: Text('Turma ${t.turma}'),
                      subtitle: Text(detalhes),
                      isThreeLine: detalhes.contains('\n'),
                      trailing: t.vagasSobrando == null
                          ? null
                          : VagasBadge(vagasSobrando: t.vagasSobrando),
                      onTap: () => Navigator.of(context).pop(t),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
