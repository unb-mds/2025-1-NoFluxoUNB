/// Lógica pura da feature Turmas — sem Flutter, sem Supabase.
///
/// Tudo aqui é função determinística e testável: formatação de "atualizado
/// há", ordenação de turmas, sanitização do termo de busca e casamento de
/// assinatura ativa com matéria/turma.
library;

import '../../../core/models/assinatura_model.dart';
import '../../../core/models/turma_model.dart';
import '../../../core/utils/busca.dart';
import '../../../core/utils/tempo_relativo.dart';

// Helpers que mudaram de casa (fonte única no core); os re-exports preservam
// os consumidores históricos desta biblioteca.
export '../../../core/services/periodo_letivo.dart' show periodoLetivoPorData;
export '../../../core/utils/busca.dart'
    show kMinCaracteresBusca, sanitizarTermoBusca;

/// O termo (já sanitizado ou não) é longo o bastante para disparar a busca?
bool termoBuscavel(String termo) =>
    sanitizarTermoBusca(termo).length >= kMinCaracteresBusca;

/// Descreve há quanto tempo o dado de vagas foi atualizado, ex.:
/// "atualizado agora", "atualizado há 5 min", "atualizado há 3 dias".
/// Wrapper fino do núcleo em core/utils/tempo_relativo.dart (datas futuras
/// contam como "agora"; nunca vira data absoluta).
String descreverAtualizadoHa(DateTime? lastUpdatedAt, {DateTime? agora}) =>
    tempoRelativo(lastUpdatedAt, agora: agora, prefixo: 'atualizado');

/// Ordena turmas para exibição: código da turma em ordem alfabética
/// (case-insensitive) e, em empate, id como desempate estável.
List<TurmaModel> ordenarTurmas(List<TurmaModel> turmas) {
  final copia = [...turmas];
  copia.sort((a, b) {
    final porTurma = a.turma.toUpperCase().compareTo(b.turma.toUpperCase());
    if (porTurma != 0) return porTurma;
    return a.idTurmas.compareTo(b.idTurmas);
  });
  return copia;
}

/// Acha a assinatura **ativa** que cobre exatamente [idMateria] + [turma].
///
/// [turma] null casa apenas com a assinatura "qualquer turma" (turma null no
/// banco); turma específica casa apenas com a assinatura daquela turma.
/// Retorna null se o usuário não segue nessa granularidade.
AssinaturaModel? assinaturaDe(
  List<AssinaturaModel> assinaturas, {
  required int idMateria,
  String? turma,
}) {
  for (final a in assinaturas) {
    if (!a.ativa || a.idMateria != idMateria) continue;
    if (a.turma == null && turma == null) return a;
    if (a.turma != null &&
        turma != null &&
        a.turma!.toUpperCase() == turma.toUpperCase()) {
      return a;
    }
  }
  return null;
}

/// Rótulo humano do alvo de uma assinatura: turma específica ou qualquer.
String descreverAlvoAssinatura(AssinaturaModel a) =>
    a.turma == null ? 'Qualquer turma' : 'Turma ${a.turma}';
