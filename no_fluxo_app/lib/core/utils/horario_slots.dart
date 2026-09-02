/// Núcleo algorítmico de horários SIGAA — porte fiel de
/// `no_fluxo_frontend_svelte/src/lib/utils/horario-slots.ts`.
///
/// Os horários da UnB são discretos: por dia há 16 módulos possíveis
/// (M1–M5, T1–T7, N1–N4) e a semana útil vai de segunda (2) a sábado (7).
/// Cada horário SIGAA (ex.: "246M12 35T34") é convertido num **bitmask
/// [BigInt]** de 96 bits (6 dias × 16 módulos), o que torna a detecção de
/// conflito uma simples operação bit-a-bit — exata e O(1), sem edge cases de
/// intervalo.
///
/// Layout do bit: `diaIndex(0..5) * 16 + offsetTurno + (modulo - 1)`,
/// com offsetTurno M=0, T=5, N=12.
library;

/// '2'(Seg)..'7'(Sáb) → 0..5.
const Map<String, int> diaIndexMap = {
  '2': 0,
  '3': 1,
  '4': 2,
  '5': 3,
  '6': 4,
  '7': 5,
};

/// Deslocamento do turno dentro do dia (16 slots/dia).
const Map<String, int> turnoOffset = {'M': 0, 'T': 5, 'N': 12};

/// Módulo máximo válido por turno (evita colisão entre turnos).
const Map<String, int> turnoMaxModulo = {'M': 5, 'T': 7, 'N': 4};

/// Mesmo padrão usado no site: dias + turno + módulos (ex.: 24M12, 6N1234).
final RegExp _horarioRegex = RegExp(r'([2-7]+)\s*([MTN])\s*([1-7]+)');

/// Colunas da grade: segunda a sábado.
const List<({String cod, String label})> diasSemana = [
  (cod: '2', label: 'Seg'),
  (cod: '3', label: 'Ter'),
  (cod: '4', label: 'Qua'),
  (cod: '5', label: 'Qui'),
  (cod: '6', label: 'Sex'),
  (cod: '7', label: 'Sáb'),
];

/// Horários reais de início de cada módulo na UnB (espelha o SLOT_MAP do site).
const Map<String, Map<int, String>> _horaInicio = {
  'M': {1: '08:00', 2: '08:55', 3: '10:00', 4: '10:55', 5: '12:00'},
  'T': {
    1: '12:55',
    2: '14:00',
    3: '14:55',
    4: '16:00',
    5: '16:55',
    6: '18:00',
    7: '18:55',
  },
  'N': {1: '19:00', 2: '19:50', 3: '20:50', 4: '21:40'},
};

/// Horários reais de fim de cada módulo (duração de 50min + intervalos).
const Map<String, Map<int, String>> _horaFim = {
  'M': {1: '08:55', 2: '09:50', 3: '10:55', 4: '11:50', 5: '12:55'},
  'T': {
    1: '13:50',
    2: '14:55',
    3: '15:50',
    4: '16:55',
    5: '17:50',
    6: '18:55',
    7: '19:50',
  },
  'N': {1: '19:50', 2: '20:40', 3: '21:40', 4: '22:30'},
};

/// Metadados de um módulo (linha da grade).
class SlotMeta {
  /// 'M', 'T' ou 'N'.
  final String turno;
  final int modulo;

  /// Deslocamento dentro do dia (0..15) — turnoOffset + (modulo-1).
  final int offset;

  /// Rótulo compacto (ex.: "M1").
  final String label;

  /// Horário de início (ex.: "08:00").
  final String inicio;

  /// Horário de fim (ex.: "08:55").
  final String fim;

  const SlotMeta({
    required this.turno,
    required this.modulo,
    required this.offset,
    required this.label,
    required this.inicio,
    required this.fim,
  });
}

/// Linhas da grade, em ordem: M1–M5, T1–T7, N1–N4.
final List<SlotMeta> slotsDia = List.unmodifiable([
  for (final turno in const ['M', 'T', 'N'])
    for (var modulo = 1; modulo <= turnoMaxModulo[turno]!; modulo++)
      SlotMeta(
        turno: turno,
        modulo: modulo,
        offset: turnoOffset[turno]! + (modulo - 1),
        label: '$turno$modulo',
        inicio: _horaInicio[turno]![modulo]!,
        fim: _horaFim[turno]![modulo]!,
      ),
]);

/// Converte um horário SIGAA num bitmask de slots da semana.
/// Retorna [BigInt.zero] para entradas vazias, nulas ou sem padrão
/// reconhecível (ex.: EAD / "A DEFINIR") — máscara vazia nunca conflita.
BigInt parseHorarioToMask(String? rawHorario) {
  final raw = (rawHorario ?? '').trim().toUpperCase();
  if (raw.isEmpty) return BigInt.zero;

  var mask = BigInt.zero;
  for (final match in _horarioRegex.allMatches(raw)) {
    final diasCod = match.group(1) ?? '';
    final turno = match.group(2) ?? 'M';
    final modulosCod = match.group(3) ?? '';
    final maxModulo = turnoMaxModulo[turno] ?? 5;

    for (final d in diasCod.split('')) {
      final diaIndex = diaIndexMap[d];
      if (diaIndex == null) continue;
      for (final m in modulosCod.split('')) {
        final modulo = int.tryParse(m) ?? 0;
        if (modulo < 1 || modulo > maxModulo) continue; // fora da faixa
        final bit = diaIndex * 16 + turnoOffset[turno]! + (modulo - 1);
        mask |= BigInt.one << bit;
      }
    }
  }
  return mask;
}

/// Duas máscaras conflitam se compartilham ao menos um slot.
bool masksConflict(BigInt a, BigInt b) => (a & b) != BigInt.zero;

/// Índice do bit para um dia (cód. SIGAA) e o offset do slot dentro do dia.
int bitIndex(String diaCod, int offsetNoDia) =>
    (diaIndexMap[diaCod] ?? 0) * 16 + offsetNoDia;

/// Máscara com todos os slots dos turnos indicados, em todos os dias.
BigInt maskDosTurnos(Iterable<String> turnos) {
  final set = turnos.toSet();
  if (set.isEmpty) return BigInt.zero;
  var mask = BigInt.zero;
  for (var dia = 0; dia < diasSemana.length; dia++) {
    for (final slot in slotsDia) {
      if (set.contains(slot.turno)) {
        mask |= BigInt.one << (dia * 16 + slot.offset);
      }
    }
  }
  return mask;
}

/// A turma cabe apenas nos turnos permitidos? Sem filtro (retorna true)
/// quando o conjunto está vazio ou tem os 3 turnos. Turma sem horário
/// (mask zero) sempre cabe.
bool turmaRespeitaTurnos(BigInt mask, Set<String> turnosPermitidos) {
  if (turnosPermitidos.isEmpty || turnosPermitidos.length == 3) return true;
  final proibidos = ['M', 'T', 'N'].where((t) => !turnosPermitidos.contains(t));
  return (mask & maskDosTurnos(proibidos)) == BigInt.zero;
}

/// Um encontro semanal concreto: dia da semana + horário real de início/fim.
class SlotHorario {
  /// Dia da semana no padrão Dart: [DateTime.monday] (1) .. sábado (6).
  final int weekday;

  /// Rótulo do dia ("Seg".."Sáb").
  final String diaLabel;

  /// Rótulo do módulo (ex.: "M1").
  final String modulo;

  /// Horário real de início (ex.: "08:00").
  final String startTime;

  /// Horário real de fim (ex.: "08:55").
  final String endTime;

  const SlotHorario({
    required this.weekday,
    required this.diaLabel,
    required this.modulo,
    required this.startTime,
    required this.endTime,
  });

  @override
  String toString() => '$diaLabel $modulo $startTime–$endTime';
}

/// Expande um horário SIGAA nos encontros semanais concretos, um por
/// dia × módulo ocupado, em ordem cronológica. Útil para a grade e para
/// agendar notificações locais.
List<SlotHorario> slotsOf(String? rawHorario) {
  final mask = parseHorarioToMask(rawHorario);
  if (mask == BigInt.zero) return const [];

  final slots = <SlotHorario>[];
  for (var dia = 0; dia < diasSemana.length; dia++) {
    for (final slot in slotsDia) {
      final bit = dia * 16 + slot.offset;
      if ((mask >> bit & BigInt.one) == BigInt.one) {
        slots.add(
          SlotHorario(
            weekday: dia + DateTime.monday,
            diaLabel: diasSemana[dia].label,
            modulo: slot.label,
            startTime: slot.inicio,
            endTime: slot.fim,
          ),
        );
      }
    }
  }
  return slots;
}

/// Descreve um horário SIGAA em texto humano com horários reais,
/// ex.: `"246M12 35T34"` → `"Seg/Qua/Sex 08:00–09:50, Ter/Qui 14:55–16:55"`.
///
/// Módulos consecutivos do mesmo grupo de dias viram um único intervalo;
/// buracos quebram em intervalos separados. Entrada sem padrão reconhecível
/// (EAD / "A DEFINIR") retorna string vazia.
String describeHorario(String? rawHorario) {
  final raw = (rawHorario ?? '').trim().toUpperCase();
  if (raw.isEmpty) return '';

  final partes = <String>[];
  for (final match in _horarioRegex.allMatches(raw)) {
    final diasCod = match.group(1) ?? '';
    final turno = match.group(2) ?? 'M';
    final modulosCod = match.group(3) ?? '';
    final maxModulo = turnoMaxModulo[turno] ?? 5;

    // Dias válidos, ordenados e sem repetição.
    final diaIndexes =
        diasCod
            .split('')
            .map((d) => diaIndexMap[d])
            .whereType<int>()
            .toSet()
            .toList()
          ..sort();
    if (diaIndexes.isEmpty) continue;
    final diasLabel = diaIndexes.map((i) => diasSemana[i].label).join('/');

    // Módulos válidos, ordenados e sem repetição.
    final modulos =
        modulosCod
            .split('')
            .map(int.tryParse)
            .whereType<int>()
            .where((m) => m >= 1 && m <= maxModulo)
            .toSet()
            .toList()
          ..sort();
    if (modulos.isEmpty) continue;

    // Agrupa módulos consecutivos num único intervalo início–fim.
    var i = 0;
    while (i < modulos.length) {
      var j = i;
      while (j + 1 < modulos.length && modulos[j + 1] == modulos[j] + 1) {
        j++;
      }
      final inicio = _horaInicio[turno]![modulos[i]]!;
      final fim = _horaFim[turno]![modulos[j]]!;
      partes.add('$diasLabel $inicio–$fim');
      i = j + 1;
    }
  }
  return partes.join(', ');
}

/// Bloco de módulos consecutivos da mesma matéria num dia (para o calendário
/// estilo "Google Agenda").
class BlocoDia {
  /// Código da matéria que ocupa o bloco.
  final String codigo;

  /// Índice do primeiro slot (posição em [slotsDia]).
  final int offsetStart;

  /// Quantos slots consecutivos o bloco cobre.
  final int span;

  const BlocoDia({
    required this.codigo,
    required this.offsetStart,
    required this.span,
  });
}

/// Agrupa módulos consecutivos da mesma matéria num único bloco. Recebe, para
/// um dia, o código que ocupa cada posição de [slotsDia] (ou null se livre).
/// Buracos e trocas de matéria quebram o bloco.
List<BlocoDia> agruparBlocosDia(List<String?> codigosPorOffset) {
  final blocos = <BlocoDia>[];
  final n = codigosPorOffset.length;
  var i = 0;
  while (i < n) {
    final codigo = codigosPorOffset[i];
    if (codigo == null || codigo.isEmpty) {
      i++;
      continue;
    }
    var j = i + 1;
    while (j < n && codigosPorOffset[j] == codigo) {
      j++;
    }
    blocos.add(BlocoDia(codigo: codigo, offsetStart: i, span: j - i));
    i = j;
  }
  return blocos;
}

// ─── Montagem automática (branch and bound) ──────────────────────────────────

/// Turma candidata na montagem automática, com o bônus de preferência já
/// calculado.
class TurmaCandidata<T> {
  final BigInt mask;
  final T turma;

  /// O quanto esta turma atende às preferências do aluno (horário/professor).
  /// É só critério de **desempate**: quem calcula os bônus deve manter `peso`
  /// de matéria > soma máxima de bônus possível.
  final num bonus;

  const TurmaCandidata({
    required this.mask,
    required this.turma,
    this.bonus = 0,
  });
}

/// Matéria com suas turmas candidatas, para o montador automático.
class MateriaTurmas<T> {
  /// Identificador da matéria (código ou id) usado como chave da seleção.
  final String chave;

  /// Turmas ofertadas, cada uma com sua máscara de horário.
  final List<TurmaCandidata<T>> turmas;

  /// Peso para priorização (default 1). Quanto maior, mais o montador prefere
  /// encaixá-la quando nem tudo cabe sem conflito.
  final num peso;

  /// Quanto a matéria consome do orçamento de créditos (default 0).
  final int creditos;

  /// Matéria que entra de qualquer jeito: gasta do orçamento, mas nunca é
  /// barrada por ele (caso da matrícula real — MATR).
  final bool obrigatoria;

  const MateriaTurmas({
    required this.chave,
    required this.turmas,
    this.peso = 1,
    this.creditos = 0,
    this.obrigatoria = false,
  });
}

/// Teto de nós explorados na montagem automática. Com a poda sensível ao
/// acumulado um pool real resolve em centenas de nós; o teto existe só para
/// garantir que nenhuma entrada inesperada trave a thread principal.
const int _maxNosMontagem = 200000;

/// Resultado de [autoMontarGrade].
class AutoMontarResult<T> {
  /// Turma escolhida por matéria (chave → turma selecionada).
  final Map<String, TurmaCandidata<T>> selecao;

  /// Chaves das matérias que não couberam — por conflito ou teto de créditos.
  final List<String> naoAlocadas;

  /// Chaves alocadas numa turma que não atinge o melhor bônus disponível —
  /// a preferência declarada teve de ceder para caber na grade.
  final List<String> preferenciasNaoAtendidas;

  /// A busca bateu no teto de nós e parou antes de esgotar as combinações.
  /// A grade devolvida é válida e sem conflito, mas pode não ser a melhor.
  final bool truncado;

  const AutoMontarResult({
    required this.selecao,
    required this.naoAlocadas,
    required this.preferenciasNaoAtendidas,
    required this.truncado,
  });
}

/// Escolhe, via *branch and bound*, uma turma por matéria de modo que nenhuma
/// sobreponha horário com outra, **maximizando** a soma dos pesos alocados.
///
/// [mascaraInicial] é horário já ocupado por fora de [materias] — matérias
/// travadas que o solver não pode mexer nem sobrepor.
///
/// [orcamentoCreditos] (opcional) é o teto de créditos da grade: matéria comum
/// só é alocada se couber no que sobra, e matéria `obrigatoria` entra de
/// qualquer forma — gastando do orçamento. Sem o argumento, créditos são
/// ignorados por completo.
///
/// Ver comentários extensos no original TS (`horario-slots.ts`) sobre a poda
/// sensível ao acumulado — sem ela, um pool com ótimo teórico inalcançável
/// varre o espaço de busca inteiro e trava a thread principal.
AutoMontarResult<T> autoMontarGrade<T>(
  List<MateriaTurmas<T>> materias, {
  BigInt? mascaraInicial,
  int? orcamentoCreditos,
}) {
  final maskInicial = mascaraInicial ?? BigInt.zero;

  bool cabeNoOrcamento(MateriaTurmas<T> m, int gasto) =>
      orcamentoCreditos == null || m.obrigatoria
      ? true
      : gasto + m.creditos <= orcamentoCreditos;

  num melhorBonusDe(MateriaTurmas<T> m) =>
      m.turmas.fold<num>(0, (max, t) => t.bonus > max ? t.bonus : max);

  // Matérias de maior peso primeiro e, dentro de cada uma, as turmas que mais
  // atendem à preferência — o primeiro mergulho já encontra uma solução boa e
  // a poda descarta o resto cedo. Turmas com a mesma máscara são
  // intercambiáveis (só o horário importa): mantém só a de maior bônus.
  final ordenadas = [...materias]..sort((a, b) => b.peso.compareTo(a.peso));
  final deduplicadas = ordenadas.map((m) {
    final porMask = <BigInt, TurmaCandidata<T>>{};
    final turmasOrdenadas = [...m.turmas]
      ..sort((x, y) => y.bonus.compareTo(x.bonus));
    for (final t in turmasOrdenadas) {
      porMask.putIfAbsent(t.mask, () => t);
    }
    return MateriaTurmas<T>(
      chave: m.chave,
      turmas: porMask.values.toList(),
      peso: m.peso,
      creditos: m.creditos,
      obrigatoria: m.obrigatoria,
    );
  }).toList();

  var melhorSelecao = <String, TurmaCandidata<T>>{};
  num melhorPeso = -1;
  final atual = <String, TurmaCandidata<T>>{};
  num pesoAtual = 0;
  var creditosAtual = 0;
  var nos = 0;
  var truncado = false;

  // Limite superior do que ainda dá para somar do índice i em diante, dado o
  // horário já ocupado. Sensível ao acumulado: matéria cujas turmas já colidem
  // todas com accMask não conta (a máscara só cresce). O orçamento entra pelo
  // mesmo motivo — relaxação da mochila, ainda é limite superior legítimo.
  num limiteSuperior(int i, BigInt accMask, int gasto) {
    num total = 0;
    for (var j = i; j < deduplicadas.length; j++) {
      final m = deduplicadas[j];
      if (!cabeNoOrcamento(m, gasto)) continue;
      for (final t in m.turmas) {
        if (masksConflict(t.mask, accMask)) continue;
        total += m.peso + t.bonus;
        break;
      }
    }
    return total;
  }

  void recurse(int i, BigInt accMask) {
    // Maximiza a soma dos pesos alocados (não só a contagem).
    if (pesoAtual > melhorPeso) {
      melhorPeso = pesoAtual;
      melhorSelecao = Map.of(atual);
    }
    if (i >= deduplicadas.length) return;
    // Rede de segurança: roda síncrono no clique do aluno. Num pool
    // patológico, para a busca e devolve a melhor grade encontrada até aqui.
    if (nos >= _maxNosMontagem) {
      truncado = true;
      return;
    }
    nos++;
    // Poda: nem alocando tudo o que ainda cabe dá para superar o melhor.
    if (pesoAtual + limiteSuperior(i, accMask, creditosAtual) <= melhorPeso) {
      return;
    }

    final m = deduplicadas[i];

    // Opção A: alocar uma turma que não conflite com o acumulado — só se a
    // matéria ainda couber no orçamento de créditos.
    if (cabeNoOrcamento(m, creditosAtual)) {
      for (final t in m.turmas) {
        if (masksConflict(t.mask, accMask)) continue;
        atual[m.chave] = t;
        pesoAtual += m.peso + t.bonus;
        creditosAtual += m.creditos;
        recurse(i + 1, accMask | t.mask);
        creditosAtual -= m.creditos;
        pesoAtual -= m.peso + t.bonus;
        atual.remove(m.chave);
      }
    }

    // Opção B: deixar esta matéria de fora e seguir.
    recurse(i + 1, accMask);
  }

  recurse(0, maskInicial);

  final naoAlocadas = <String>[];
  final preferenciasNaoAtendidas = <String>[];
  for (final m in materias) {
    final escolhida = melhorSelecao[m.chave];
    if (escolhida == null) {
      naoAlocadas.add(m.chave);
      continue;
    }
    final melhor = melhorBonusDe(m);
    // Só reporta quem declarou preferência (melhor > 0) e não conseguiu.
    if (melhor > 0 && escolhida.bonus < melhor) {
      preferenciasNaoAtendidas.add(m.chave);
    }
  }

  return AutoMontarResult(
    selecao: melhorSelecao,
    naoAlocadas: naoAlocadas,
    preferenciasNaoAtendidas: preferenciasNaoAtendidas,
    truncado: truncado,
  );
}
