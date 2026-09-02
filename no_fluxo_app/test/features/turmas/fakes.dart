/// Fakes compartilhados dos testes da feature Turmas.
library;

import 'package:no_fluxo_app/core/models/assinatura_model.dart';
import 'package:no_fluxo_app/core/models/materia_model.dart';
import 'package:no_fluxo_app/core/models/turma_model.dart';
import 'package:no_fluxo_app/features/turmas/data/turmas_repository.dart';
import 'package:no_fluxo_app/features/turmas/domain/turmas_logic.dart';

/// Registro de uma chamada à RPC `seguir_materia` no fake.
typedef ChamadaSeguir = ({int idMateria, String? turma, String anoPeriodo});

/// Repositório em memória: registra as chamadas às RPCs para os testes
/// verificarem os parâmetros, e mantém as assinaturas consistentes.
class FakeTurmasRepository implements TurmasRepository {
  final List<MateriaModel> materias;
  final Map<int, List<TurmaModel>> turmasPorMateria;
  final List<AssinaturaModel> assinaturas;
  final String periodo;

  /// Chamadas registradas a `seguir_materia`.
  final List<ChamadaSeguir> chamadasSeguir = [];

  /// Ids passados a `deixar_de_seguir_materia`.
  final List<int> chamadasDeixarDeSeguir = [];

  int _proximoIdAssinatura = 1000;

  FakeTurmasRepository({
    this.materias = const [],
    this.turmasPorMateria = const {},
    List<AssinaturaModel>? assinaturas,
    this.periodo = '2026.1',
  }) : assinaturas = [...?assinaturas];

  @override
  Future<List<MateriaModel>> buscarMaterias(
    String termo, {
    int limite = 40,
  }) async {
    final safe = sanitizarTermoBusca(termo).toUpperCase();
    if (safe.length < kMinCaracteresBusca) return const [];
    return materias
        .where(
          (m) =>
              m.codigoMateria.toUpperCase().contains(safe) ||
              m.nomeMateria.toUpperCase().contains(safe),
        )
        .take(limite)
        .toList();
  }

  @override
  Future<String> periodoAtual() async => periodo;

  @override
  Future<List<TurmaModel>> turmasDaMateria(int idMateria) async {
    return ordenarTurmas(turmasPorMateria[idMateria] ?? const []);
  }

  @override
  Future<AssinaturaModel> seguirMateria({
    required int idMateria,
    String? turma,
    required String anoPeriodo,
  }) async {
    chamadasSeguir.add((
      idMateria: idMateria,
      turma: turma,
      anoPeriodo: anoPeriodo,
    ));
    final nova = AssinaturaModel(
      idAssinatura: _proximoIdAssinatura++,
      idMateria: idMateria,
      turma: turma,
      anoPeriodo: anoPeriodo,
    );
    assinaturas.add(nova);
    return nova;
  }

  @override
  Future<void> deixarDeSeguirMateria(int idAssinatura) async {
    chamadasDeixarDeSeguir.add(idAssinatura);
    assinaturas.removeWhere((a) => a.idAssinatura == idAssinatura);
  }

  @override
  Future<List<AssinaturaModel>> listarMinhasAssinaturas() async {
    return [...assinaturas];
  }
}

/// Matéria de exemplo usada nos testes.
MateriaModel materiaCic0004() => MateriaModel(
  ementa: '',
  idMateria: 1,
  nomeMateria: 'Algoritmos e Programação de Computadores',
  codigoMateria: 'CIC0004',
  nivel: 1,
  creditos: 6,
);

/// Turma de exemplo (com vagas e horário SIGAA).
TurmaModel turmaExemplo({
  int idTurmas = 10,
  int idMateria = 1,
  String turma = '01',
  int? vagasSobrando = 5,
  String? horario = '246M12',
  DateTime? lastUpdatedAt,
}) => TurmaModel(
  idTurmas: idTurmas,
  idMateria: idMateria,
  turma: turma,
  docente: 'FULANO DE TAL',
  horario: horario,
  local: 'PJC BT 076',
  anoPeriodo: '2026.1',
  vagasOfertadas: 40,
  vagasOcupadas: vagasSobrando == null ? null : 40 - vagasSobrando,
  vagasSobrando: vagasSobrando,
  lastUpdatedAt: lastUpdatedAt,
);
