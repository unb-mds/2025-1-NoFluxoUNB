/// Lógica pura da grade horária semanal do aluno.
///
/// Nenhuma dependência de plugin ou IO: recebe turmas e um relógio (`now`)
/// injetável e devolve estruturas prontas para a UI e para o agendador de
/// notificações — tudo testável em Dart puro.
library;

import '../../../core/models/turma_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/utils/horario_slots.dart';

/// Turma que compõe a grade do aluno, com a origem.
///
/// [manual] distingue a turma adicionada à mão (fonte 2, removível) da turma
/// derivada do fluxograma — matéria com status MATR (fonte 1).
class TurmaGrade {
  final TurmaModel turma;
  final bool manual;

  const TurmaGrade({required this.turma, this.manual = false});
}

/// Bloco de aula na grade: módulos consecutivos da mesma turma num dia.
///
/// Ex.: "2M12" vira um único bloco Seg 08:00–09:50.
class BlocoAula {
  /// Dia no padrão Dart: [DateTime.monday] (1) .. sábado (6).
  final int weekday;

  /// Rótulo do dia ("Seg".."Sáb").
  final String diaLabel;

  /// Horário real de início (ex.: "08:00").
  final String inicio;

  /// Horário real de fim (ex.: "09:50").
  final String fim;

  /// Offset do primeiro módulo dentro do dia (0..15) — usado para ordenar e
  /// para gerar ids estáveis de notificação.
  final int offsetInicio;

  /// Código da matéria (ex.: "FGA0138").
  final String codigo;

  /// Nome da matéria (cai para o código quando desconhecido).
  final String nome;

  /// Letra/número da turma no SIGAA (ex.: "01").
  final String turmaLabel;

  final String? local;
  final String? docente;
  final int idTurmas;

  /// A turma dona do bloco foi adicionada manualmente?
  final bool manual;

  /// Algum módulo deste bloco é disputado por outra turma da grade?
  final bool conflito;

  const BlocoAula({
    required this.weekday,
    required this.diaLabel,
    required this.inicio,
    required this.fim,
    required this.offsetInicio,
    required this.codigo,
    required this.nome,
    required this.turmaLabel,
    required this.idTurmas,
    this.local,
    this.docente,
    this.manual = false,
    this.conflito = false,
  });
}

/// Grade semanal montada: blocos por dia + diagnóstico de conflitos.
class GradeSemanal {
  /// weekday (1=Seg .. 6=Sáb) → blocos ordenados por horário de início.
  /// Dias sem aula não aparecem no mapa.
  final Map<int, List<BlocoAula>> blocosPorDia;

  /// `idTurmas` das turmas que disputam ao menos um módulo com outra.
  final Set<int> turmasEmConflito;

  /// Turmas sem horário reconhecível (EAD / "A DEFINIR") — ficam fora dos
  /// blocos mas o aluno precisa vê-las listadas.
  final List<TurmaGrade> semHorario;

  const GradeSemanal({
    required this.blocosPorDia,
    required this.turmasEmConflito,
    required this.semHorario,
  });

  bool get vazia => blocosPorDia.isEmpty && semHorario.isEmpty;

  /// Dias com aula, em ordem (Seg → Sáb).
  List<int> get diasComAula => blocosPorDia.keys.toList()..sort();

  /// Todos os blocos da semana, sem garantia de ordem entre dias.
  Iterable<BlocoAula> get todosBlocos => blocosPorDia.values.expand((b) => b);
}

/// Monta a grade semanal a partir das turmas do aluno.
///
/// - Turmas duplicadas (mesmo `idTurmas`) são consideradas uma vez só.
/// - Módulos consecutivos da mesma turma no mesmo dia viram um bloco único.
/// - Conflito é detectado bit a bit ([masksConflict]) e marcado tanto no
///   nível da turma ([GradeSemanal.turmasEmConflito]) quanto no bloco que
///   contém o módulo disputado ([BlocoAula.conflito]).
GradeSemanal montarGradeSemanal(List<TurmaGrade> turmas) {
  // Dedup por idTurmas — a mesma turma pode vir da fonte automática e manual.
  final vistas = <int>{};
  final unicas = <TurmaGrade>[
    for (final t in turmas)
      if (vistas.add(t.turma.idTurmas)) t,
  ];

  final masks = <int, BigInt>{
    for (final t in unicas)
      t.turma.idTurmas: parseHorarioToMask(t.turma.horario),
  };

  // Ocupação de cada bit da semana (dia*16 + offset) → quantas turmas o usam.
  final ocupacao = <int, int>{};
  for (final mask in masks.values) {
    for (var bit = 0; bit < 96; bit++) {
      if ((mask >> bit & BigInt.one) == BigInt.one) {
        ocupacao[bit] = (ocupacao[bit] ?? 0) + 1;
      }
    }
  }

  // Turmas em conflito: qualquer par com interseção de máscara.
  final emConflito = <int>{};
  for (var i = 0; i < unicas.length; i++) {
    for (var j = i + 1; j < unicas.length; j++) {
      final a = unicas[i].turma.idTurmas;
      final b = unicas[j].turma.idTurmas;
      if (masksConflict(masks[a]!, masks[b]!)) {
        emConflito.add(a);
        emConflito.add(b);
      }
    }
  }

  final blocosPorDia = <int, List<BlocoAula>>{};
  final semHorario = <TurmaGrade>[];

  for (final tg in unicas) {
    final mask = masks[tg.turma.idTurmas]!;
    if (mask == BigInt.zero) {
      semHorario.add(tg);
      continue;
    }

    for (var dia = 0; dia < diasSemana.length; dia++) {
      bool ocupado(int offset) =>
          (mask >> (dia * 16 + offset) & BigInt.one) == BigInt.one;

      var offset = 0;
      while (offset < slotsDia.length) {
        if (!ocupado(offset)) {
          offset++;
          continue;
        }
        // Estende o bloco enquanto os módulos seguintes forem da mesma turma.
        var fimOffset = offset;
        while (fimOffset + 1 < slotsDia.length && ocupado(fimOffset + 1)) {
          fimOffset++;
        }
        var conflito = false;
        for (var o = offset; o <= fimOffset; o++) {
          if ((ocupacao[dia * 16 + o] ?? 0) > 1) conflito = true;
        }

        final codigo = tg.turma.codigoMateria?.trim().isNotEmpty == true
            ? tg.turma.codigoMateria!.trim()
            : '—';
        blocosPorDia
            .putIfAbsent(dia + DateTime.monday, () => [])
            .add(
              BlocoAula(
                weekday: dia + DateTime.monday,
                diaLabel: diasSemana[dia].label,
                inicio: slotsDia[offset].inicio,
                fim: slotsDia[fimOffset].fim,
                offsetInicio: offset,
                codigo: codigo,
                nome: tg.turma.nomeMateria?.trim().isNotEmpty == true
                    ? tg.turma.nomeMateria!.trim()
                    : codigo,
                turmaLabel: tg.turma.turma,
                idTurmas: tg.turma.idTurmas,
                local: tg.turma.local,
                docente: tg.turma.docente,
                manual: tg.manual,
                conflito: conflito,
              ),
            );
        offset = fimOffset + 1;
      }
    }
  }

  for (final blocos in blocosPorDia.values) {
    blocos.sort((a, b) => a.offsetInicio.compareTo(b.offsetInicio));
  }

  return GradeSemanal(
    blocosPorDia: blocosPorDia,
    turmasEmConflito: emConflito,
    semHorario: semHorario,
  );
}

/// Matérias em curso (MATR) do fluxograma que têm turma registrada —
/// os pares (código, turma) usados para buscar a oferta na tabela `turmas`.
List<({String codigo, String turma})> materiasEmCursoComTurma(
  DadosFluxogramaUser dados,
) {
  final vistos = <String>{};
  final pares = <({String codigo, String turma})>[];
  for (final m in dados.todasMaterias) {
    if (!m.isEmCurso) continue;
    final codigo = m.codigoMateria.trim().toUpperCase();
    final turma = (m.turma ?? '').trim().toUpperCase();
    if (codigo.isEmpty || turma.isEmpty) continue;
    if (vistos.add('$codigo|$turma')) {
      pares.add((codigo: codigo, turma: turma));
    }
  }
  return pares;
}

/// Aula em destaque na tela: a que está acontecendo agora ou, na falta, a
/// próxima a começar (janela de 7 dias).
class DestaqueAula {
  final BlocoAula bloco;

  /// true = aula em andamento neste instante; false = é a próxima a começar.
  final bool emAndamento;

  const DestaqueAula({required this.bloco, required this.emAndamento});
}

(int, int) _horaMinuto(String hhmm) =>
    (int.parse(hhmm.substring(0, 2)), int.parse(hhmm.substring(3, 5)));

/// Encontra a aula em andamento (prioridade) ou a próxima a começar depois de
/// [now]. Retorna null para grade sem blocos.
DestaqueAula? aulaEmDestaque(GradeSemanal grade, DateTime now) {
  BlocoAula? proxima;
  DateTime? proximaInicio;

  for (final bloco in grade.todosBlocos) {
    final (hIni, mIni) = _horaMinuto(bloco.inicio);
    final (hFim, mFim) = _horaMinuto(bloco.fim);
    // Ocorrência do bloco nesta semana (0 = hoje, 6 = daqui a 6 dias).
    final delta = (bloco.weekday - now.weekday) % 7;
    var inicio = DateTime(now.year, now.month, now.day + delta, hIni, mIni);
    final fim = DateTime(now.year, now.month, now.day + delta, hFim, mFim);

    if (delta == 0 && !now.isBefore(inicio) && now.isBefore(fim)) {
      return DestaqueAula(bloco: bloco, emAndamento: true);
    }
    if (!inicio.isAfter(now)) {
      // Já passou hoje → próxima semana.
      inicio = DateTime(now.year, now.month, now.day + 7, hIni, mIni);
    }
    if (proximaInicio == null || inicio.isBefore(proximaInicio)) {
      proximaInicio = inicio;
      proxima = bloco;
    }
  }

  if (proxima == null) return null;
  return DestaqueAula(bloco: proxima, emAndamento: false);
}

/// Um disparo de notificação local calculado — sem tocar em plugin nenhum.
class AgendamentoNotificacao {
  /// Id estável (mesmo bloco → mesmo id), próprio para regravar agendamentos.
  final int id;

  /// Momento do disparo (início da aula menos a antecedência), no fuso local.
  final DateTime dateTime;

  final String titulo;
  final String corpo;

  /// Dia da semana da aula (padrão Dart) — o agendador usa recorrência
  /// semanal ancorada neste dia+horário.
  final int weekday;

  const AgendamentoNotificacao({
    required this.id,
    required this.dateTime,
    required this.titulo,
    required this.corpo,
    required this.weekday,
  });
}

/// Calcula os agendamentos de notificação de "aula começando".
///
/// Para cada bloco de aula, gera as próximas [ocorrenciasPorBloco] ocorrências
/// semanais cujo disparo (início − [antecedencia]) ainda está no futuro de
/// [now]. O relógio é injetado para os testes serem determinísticos.
///
/// Resultado ordenado por [AgendamentoNotificacao.dateTime].
List<AgendamentoNotificacao> calcularAgendamentos({
  required List<TurmaGrade> turmas,
  required DateTime now,
  Duration antecedencia = const Duration(minutes: 30),
  int ocorrenciasPorBloco = 1,
}) {
  final grade = montarGradeSemanal(turmas);
  final agendamentos = <AgendamentoNotificacao>[];

  for (final bloco in grade.todosBlocos) {
    final (hora, minuto) = _horaMinuto(bloco.inicio);

    // Primeira ocorrência da aula cujo disparo ainda é futuro.
    var aula = DateTime(now.year, now.month, now.day, hora, minuto);
    while (aula.weekday != bloco.weekday ||
        !aula.subtract(antecedencia).isAfter(now)) {
      aula = DateTime(aula.year, aula.month, aula.day + 1, hora, minuto);
    }

    for (var k = 0; k < ocorrenciasPorBloco; k++) {
      // Id estável: turma × bit da semana × índice da ocorrência.
      // 96 bits/semana e idTurmas na casa das dezenas de milhar mantêm o
      // resultado bem abaixo do teto de 32 bits exigido pelo Android.
      final bit = (bloco.weekday - DateTime.monday) * 16 + bloco.offsetInicio;
      final id = (bloco.idTurmas * 96 + bit) * 8 + k;

      agendamentos.add(
        AgendamentoNotificacao(
          id: id,
          dateTime: aula.subtract(antecedencia),
          titulo: '${bloco.codigo} começa em ${antecedencia.inMinutes} min',
          corpo:
              '${bloco.nome} · ${bloco.inicio}–${bloco.fim} · ${bloco.local?.trim().isNotEmpty == true ? bloco.local!.trim() : 'Local a definir'}',
          weekday: bloco.weekday,
        ),
      );

      aula = DateTime(aula.year, aula.month, aula.day + 7, hora, minuto);
    }
  }

  agendamentos.sort((a, b) => a.dateTime.compareTo(b.dateTime));
  return agendamentos;
}
