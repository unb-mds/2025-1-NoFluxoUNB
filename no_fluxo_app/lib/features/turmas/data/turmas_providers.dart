import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/assinatura_model.dart';
import '../../../core/models/materia_model.dart';
import '../../../core/models/turma_model.dart';
import '../../../core/services/auth_service.dart';
import 'turmas_repository.dart';

/// Usuário tem sessão de verdade (não visitante)? Só logado pode assinar
/// alertas de vaga — as RPCs exigem JWT.
///
// O provider mudou de casa (é infraestrutura de auth, não de turmas); o
// re-export preserva os consumidores e overrides históricos desta biblioteca.
export '../../../core/services/auth_service.dart' show estaLogadoProvider;

/// Período letivo ativo (ex.: "2026.1").
final periodoAtualProvider = FutureProvider<String>((ref) {
  return ref.watch(turmasRepositoryProvider).periodoAtual();
});

/// Resultado da busca de matérias para um termo já digitado.
final buscarMateriasProvider = FutureProvider.autoDispose
    .family<List<MateriaModel>, String>((ref, termo) {
      return ref.watch(turmasRepositoryProvider).buscarMaterias(termo);
    });

/// Turmas ofertadas de uma matéria no período atual.
final turmasDaMateriaProvider = FutureProvider.autoDispose
    .family<List<TurmaModel>, int>((ref, idMateria) {
      return ref.watch(turmasRepositoryProvider).turmasDaMateria(idMateria);
    });

/// Assinaturas de vaga do usuário logado, com ações de seguir/deixar de
/// seguir que mantêm a lista sincronizada.
class AssinaturasNotifier extends AsyncNotifier<List<AssinaturaModel>> {
  @override
  Future<List<AssinaturaModel>> build() async {
    // Visitante/deslogado não tem assinaturas — e a RPC falharia sem JWT.
    if (!ref.watch(estaLogadoProvider)) return const [];
    return ref.watch(turmasRepositoryProvider).listarMinhasAssinaturas();
  }

  /// Fila das mutações: seguir/deixar de seguir concorrentes rodavam em
  /// paralelo e a recarga da mais lenta sobrescrevia a da mais recente
  /// (write-last-wins). Encadear no mesmo Future serializa tudo.
  Future<void> _fila = Future.value();

  Future<String?> _enfileirar(Future<String?> Function() mutacao) {
    final resultado = _fila.then((_) => mutacao());
    // Erros já viram mensagem dentro da mutação; a fila nunca quebra.
    _fila = resultado.then((_) {}, onError: (_) {});
    return resultado;
  }

  /// Segue a matéria ([turma] null = qualquer turma). Retorna null em
  /// sucesso ou uma mensagem de erro para exibir.
  Future<String?> seguir({
    required int idMateria,
    String? turma,
    required String anoPeriodo,
  }) {
    return _enfileirar(() async {
      try {
        final repo = ref.read(turmasRepositoryProvider);
        await repo.seguirMateria(
          idMateria: idMateria,
          turma: turma,
          anoPeriodo: anoPeriodo,
        );
        state = AsyncData(await repo.listarMinhasAssinaturas());
        return null;
      } catch (_) {
        return 'Não foi possível seguir a matéria. Tente novamente.';
      }
    });
  }

  /// Remove a assinatura. Retorna null em sucesso ou mensagem de erro.
  Future<String?> deixarDeSeguir(int idAssinatura) {
    return _enfileirar(() async {
      try {
        final repo = ref.read(turmasRepositoryProvider);
        await repo.deixarDeSeguirMateria(idAssinatura);
        state = AsyncData(await repo.listarMinhasAssinaturas());
        return null;
      } catch (_) {
        return 'Não foi possível remover o alerta. Tente novamente.';
      }
    });
  }
}

/// Assinaturas ativas do usuário (lista vazia para visitante).
final assinaturasProvider =
    AsyncNotifierProvider<AssinaturasNotifier, List<AssinaturaModel>>(
      AssinaturasNotifier.new,
    );
