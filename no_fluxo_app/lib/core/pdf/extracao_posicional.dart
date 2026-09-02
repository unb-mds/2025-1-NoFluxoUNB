/// Extração posicional das disciplinas regulares — porte fiel de
/// no_fluxo_frontend_svelte/src/lib/services/pdf/pdfPositionExtractor.ts.
///
/// O histórico SIGAA é uma tabela com colunas em faixas de X conhecidas;
/// itens com o mesmo Y pertencem à mesma linha.
library;

import 'extracao_texto.dart';
import 'modelos_extracao.dart';

// ─── Layout das colunas ───

/// Limites default das colunas (mesmos valores de `DEFAULT_COLUMNS` no site);
/// a detecção pela linha de cabeçalho pode sobrescrever alguns campos.
class _LimitesColunas {
  double periodMax = 75;
  double symbolMin = 75;
  double symbolMax = 88;
  double codeMin = 88;
  double codeMax = 128;
  double contentMin = 128;
  double contentMax = 410;
  double chMin = 410;
  double chMax = 440;
  double turmaMin = 440;
  double turmaMax = 470;
  double freqMin = 470;
  double freqMax = 502;
  double notaMin = 502;
  double notaMax = 530;
  double sitMin = 530;
}

// ─── Linha classificada ───

enum _TipoLinha { data, nameOnly, header, metadata, continuation, unknown }

class _LinhaClassificada {
  final double y;
  final int page;
  final String period;
  final String symbol;
  final String code;
  final String content;
  final String ch;
  final String turma;
  final String freq;
  final String nota;
  final String situacao;
  _TipoLinha rowType;

  _LinhaClassificada({
    required this.y,
    required this.page,
    required this.period,
    required this.symbol,
    required this.code,
    required this.content,
    required this.ch,
    required this.turma,
    required this.freq,
    required this.nota,
    required this.situacao,
    required this.rowType,
  });
}

// ─── Detecção de colunas ───

_LimitesColunas _detectarColunas(List<List<ItemPosicionado>> paginas) {
  // Procura a linha de cabeçalho com "CH", "Turma", "Freq", "Nota", "Situação"
  for (final itensPagina in paginas) {
    for (final (_, itensLinha) in agruparItensEmLinhas(itensPagina)) {
      final textos = itensLinha.map((it) => it.text).toList();
      final junto = textos.join(' ');
      if (junto.contains('CH') &&
          (junto.contains('Turma') || junto.contains('Situação'))) {
        // Achou o cabeçalho — extrai as posições das colunas
        final cols = _LimitesColunas();
        for (final item in itensLinha) {
          final t = item.text;
          if (t == 'CH') {
            cols.chMin = item.x - 5;
            cols.chMax = item.x + item.width + 15;
            cols.contentMax = item.x - 5;
          } else if (t == 'Turma') {
            cols.turmaMin = item.x - 5;
            cols.turmaMax = item.x + item.width + 10;
          } else if (t.startsWith('Freq')) {
            cols.freqMin = item.x - 5;
            cols.freqMax = item.x + 25; // freq + % na coluna seguinte
          } else if (t == 'Nota') {
            cols.notaMin = item.x - 5;
            cols.notaMax = item.x + item.width + 10;
          } else if (t == 'Situação') {
            cols.sitMin = item.x - 5;
          }
        }
        return cols;
      }
    }
  }

  return _LimitesColunas();
}

// ─── Classificação de linhas ───

final _reStatusValido = RegExp(
  r'^(APR|REP|REPF|REPMF|CANC|DISP|TRANC|MATR|CUMP)$',
);
final _rePeriodo = RegExp(r'^(\d{4}\.?\d?|--)$');
final _reCodigo = RegExp(r'^[A-Z]{2,}\d{3,}$');
final _reInicioProfessor = RegExp(
  r'(?:^|\b)(?:Dr\.|Dra\.|MSc\.|Prof\.)\s',
  caseSensitive: false,
);
final _reHorasProfessor = RegExp(r'\(\d+h\)');

final _padroesMetadados = <RegExp>[
  RegExp(r'^SIGAA\b', caseSensitive: false),
  RegExp(r'^UnB\b', caseSensitive: false),
  RegExp(r'^DEG\b', caseSensitive: false),
  RegExp(r'^SAA\b', caseSensitive: false),
  RegExp(r'^Campus\b', caseSensitive: false),
  RegExp(r'^Credenciada\b', caseSensitive: false),
  RegExp(r'^na seção', caseSensitive: false),
  RegExp(r'^Histórico Escolar', caseSensitive: false),
  RegExp(r'^Dados', caseSensitive: false),
  RegExp(r'^Nome:', caseSensitive: false),
  RegExp(r'^Data de', caseSensitive: false),
  RegExp(r'^Nacionalidade', caseSensitive: false),
  RegExp(r'^Nº do', caseSensitive: false),
  RegExp(r'^Curso:', caseSensitive: false),
  RegExp(r'^Status:', caseSensitive: false),
  RegExp(r'^Índices', caseSensitive: false),
  RegExp(r'^Ênfase', caseSensitive: false),
  RegExp(r'^IRA:', caseSensitive: false),
  RegExp(r'^Currículo', caseSensitive: false),
  RegExp(r'^MP:', caseSensitive: false),
  RegExp(r'^Reconhecimento', caseSensitive: false),
  RegExp(r'^Ano\s*/?\s*Período', caseSensitive: false),
  RegExp(r'^Forma de', caseSensitive: false),
  RegExp(r'^Período Letivo', caseSensitive: false),
  RegExp(r'^Suspens[õo]es', caseSensitive: false),
  RegExp(r'^Prorrogações', caseSensitive: false),
  RegExp(r'^Tipo Saída', caseSensitive: false),
  RegExp(r'^Data da', caseSensitive: false),
  RegExp(r'^Trabalho de', caseSensitive: false),
  RegExp(r'^Para verificar', caseSensitive: false),
  RegExp(r'^Página', caseSensitive: false),
  RegExp(r'^e o código', caseSensitive: false),
  RegExp(r'^Componentes Curriculares', caseSensitive: false),
  RegExp(r'^Código\s+Componente', caseSensitive: false),
  RegExp(r'^Observações', caseSensitive: false),
  RegExp(r'^Atenção', caseSensitive: false),
  RegExp(r'^Menções', caseSensitive: false),
  RegExp(r'^Equivalências', caseSensitive: false),
  RegExp(r'^Matrícula', caseSensitive: false),
  RegExp(r'^Perfil', caseSensitive: false),
  RegExp(r'^Prazo', caseSensitive: false),
  RegExp(r'^Legenda', caseSensitive: false),
  RegExp(r'^SIGLA', caseSensitive: false),
  RegExp(r'^Carga Horária', caseSensitive: false),
  RegExp(r'^Obrigatórias', caseSensitive: false),
  RegExp(r'^Optativos', caseSensitive: false),
  RegExp(r'^Complementares', caseSensitive: false),
  RegExp(r'^Total', caseSensitive: false),
  RegExp(r'^Exigido', caseSensitive: false),
  RegExp(r'^Integralizado', caseSensitive: false),
  RegExp(r'^Pendente', caseSensitive: false),
  RegExp(r'^Nenhum', caseSensitive: false),
  RegExp(r'^Descrição', caseSensitive: false),
  RegExp(r'^INGRESSANTE', caseSensitive: false),
  RegExp(r'^Letivo\s+Componente', caseSensitive: false),
  RegExp(r'^\d+\s*períodos?\s*letivos?', caseSensitive: false),
  RegExp(r'^Sistema Integrado', caseSensitive: false),
  RegExp(r'^Universidade', caseSensitive: false),
  RegExp(r'^Decanato', caseSensitive: false),
  RegExp(r'^Secretaria', caseSensitive: false),
  RegExp(r'^Centro de Vivência', caseSensitive: false),
  RegExp(r'^Asa Norte', caseSensitive: false),
  RegExp(r'^CEP\b', caseSensitive: false),
  RegExp(r'^Leonardo\b', caseSensitive: false),
  RegExp(r'^Portaria', caseSensitive: false),
  RegExp(r'^ENEM', caseSensitive: false),
];

bool _ehTextoMetadado(String texto) {
  final t = texto.trim();
  for (final re in _padroesMetadados) {
    if (re.hasMatch(t)) return true;
  }
  return false;
}

final _reSimbolo = RegExp(r'^[*&#e@§%#]$');
final _reAnoSolto = RegExp(r'^\d{4}$');
final _reContinuacaoPeriodo = RegExp(r'^\.\d$');
final _reHeaderContinuacao = RegExp(r'^Ano/?Período$', caseSensitive: false);
final _reInicioNome = RegExp(r'^[A-ZÀ-ÿ(]');

_LinhaClassificada _classificarLinha(
  double y,
  int page,
  List<ItemPosicionado> itens,
  _LimitesColunas cols,
) {
  // Ordena da esquerda para a direita
  final ordenados = [...itens]..sort((a, b) => a.x.compareTo(b.x));

  var period = '';
  var symbol = '';
  var code = '';
  final contentParts = <String>[];
  var ch = '';
  var turma = '';
  var freq = '';
  var nota = '';
  var situacao = '';

  for (final item in ordenados) {
    final x = item.x;
    final t = item.text;

    if (x < cols.periodMax) {
      // Coluna do período — filtra números de página etc.
      if (_rePeriodo.hasMatch(t) || _reAnoSolto.hasMatch(t)) {
        period = period.isNotEmpty ? period + t : t;
      } else {
        // Pode ser continuação do período (".1")
        if (_reContinuacaoPeriodo.hasMatch(t)) {
          period = period + t;
        }
      }
    } else if (x >= cols.symbolMin && x < cols.symbolMax) {
      // Coluna do símbolo
      if (_reSimbolo.hasMatch(t)) {
        symbol = t;
      } else if (_reCodigo.hasMatch(t)) {
        code = t;
      }
    } else if (x >= cols.codeMin && x < cols.codeMax) {
      // Coluna do código
      if (_reCodigo.hasMatch(t)) {
        code = t;
      } else {
        // Às vezes o código não está perfeitamente alinhado
        contentParts.add(t);
      }
    } else if (x >= cols.contentMin && x < cols.contentMax) {
      contentParts.add(t);
    } else if (x >= cols.chMin && x < cols.chMax) {
      ch = t;
    } else if (x >= cols.turmaMin && x < cols.turmaMax) {
      if (turma.isEmpty) {
        turma = t;
      } else {
        turma += t;
      }
    } else if (x >= cols.freqMin && x < cols.freqMax) {
      if (freq.isEmpty) {
        freq = t;
      } else {
        freq += t;
      }
    } else if (x >= cols.notaMin && x < cols.notaMax) {
      if (nota.isEmpty) {
        nota = t;
      } else {
        nota += t;
      }
    } else if (x >= cols.sitMin) {
      if (situacao.isEmpty) {
        situacao = t;
      } else {
        situacao += t;
      }
    }
  }

  final content = contentParts.join(' ');

  // Determina o tipo da linha
  var rowType = _TipoLinha.unknown;

  if (content.contains('Componente') &&
      (content.contains('Curricular') || content.contains('CH'))) {
    rowType = _TipoLinha.header;
  } else if (content == 'Letivo' || _reHeaderContinuacao.hasMatch(content)) {
    rowType = _TipoLinha.header;
  } else if (_ehTextoMetadado(content) ||
      _ehTextoMetadado('$period $content')) {
    rowType = _TipoLinha.metadata;
  } else if ((period.isNotEmpty || code.isNotEmpty) &&
      _reStatusValido.hasMatch(situacao)) {
    rowType = _TipoLinha.data;
  } else if ((period.isNotEmpty || code.isNotEmpty) &&
      ch.isNotEmpty &&
      situacao.isEmpty) {
    // Pode ser linha de dados com situação misturada na nota
    rowType = _TipoLinha.data;
  } else if (content.isNotEmpty &&
      period.isEmpty &&
      code.isEmpty &&
      ch.isEmpty &&
      turma.isEmpty &&
      situacao.isEmpty) {
    // Linha só de nome, continuação de professor, ou desconhecida?
    if (_reHorasProfessor.hasMatch(content) && content.length < 20) {
      rowType = _TipoLinha.continuation;
    } else if (_reInicioProfessor.hasMatch(content)) {
      rowType = _TipoLinha.continuation;
    } else if (content.length > 2 && _reInicioNome.hasMatch(content)) {
      rowType = _TipoLinha.nameOnly;
    } else {
      rowType = _TipoLinha.unknown;
    }
  }

  return _LinhaClassificada(
    y: y,
    page: page,
    period: period,
    symbol: symbol,
    code: code,
    content: content,
    ch: ch,
    turma: turma,
    freq: freq,
    nota: nota,
    situacao: situacao,
    rowType: rowType,
  );
}

// ─── Nome e professor a partir do conteúdo ───

final _reProfessorEmbutido = RegExp(
  r'(?:Dr\.|Dra\.|MSc\.|Prof\.)\s',
  caseSensitive: false,
);

({String name, String professor}) _separarProfessorENome(String content) {
  if (content.isEmpty) return (name: '', professor: '');

  // Conteúdo começa com padrão de professor?
  if (_reInicioProfessor.hasMatch(content)) {
    return (name: '', professor: content);
  }

  // Professor embutido depois do nome? ex.: "NOME Dr. FULANO (60h)"
  final profIdx = _reProfessorEmbutido.firstMatch(content)?.start ?? -1;
  if (profIdx > 0) {
    return (
      name: content.substring(0, profIdx).trim(),
      professor: content.substring(profIdx).trim(),
    );
  }

  // É tudo nome
  return (name: content, professor: '');
}

// ─── Limpeza do nome do professor ───

String _limparNomeProfessor(String raw) {
  if (raw.isEmpty) return '';

  // Multi-professor: "Dr. NOME1 (30h), Dr. NOME2 (30h)"
  final partes = raw.split(RegExp(r',\s*'));
  final nomes = <String>[];

  for (var parte in partes) {
    parte = parte.trim();
    if (parte.isEmpty) continue;

    // Remove o prefixo de título
    parte = parte.replaceFirst(
      RegExp(
        r'^(?:Dr\.|Dra\.|MSc\.|Prof\.|PhD\.?|Me\.|Ma\.)\s*',
        caseSensitive: false,
      ),
      '',
    );

    // Remove padrões (Xh)
    parte = parte.replaceAll(RegExp(r'\s*\(\d+h\)'), '');

    // Remove sobras não alfabéticas nas pontas
    parte = parte.replaceFirst(RegExp(r'[^a-zA-ZÀ-ÿ\s]+$'), '');
    parte = parte.replaceFirst(RegExp(r'^\s*[^a-zA-ZÀ-ÿ]+'), '');
    parte = parte.replaceAll(RegExp(r'\s{2,}'), ' ').trim();

    if (parte.length > 1) {
      nomes.add(parte);
    }
  }

  return nomes.join(', ');
}

// ─── Limpeza do nome da disciplina ───

String limparNomeDisciplina(String raw) {
  var limpo = raw;

  // Remove prefixo de período incluído por engano
  limpo = limpo.replaceFirst(RegExp(r'^\d{4}\.\d\s*'), '');
  limpo = limpo.replaceFirst(RegExp(r'^--\s*'), '');

  // Remove não alfanuméricos das pontas
  limpo = limpo.replaceFirst(RegExp(r'^[^a-zA-ZÀ-ÿ0-9]+'), '');
  limpo = limpo.replaceFirst(RegExp(r'[^a-zA-ZÀ-ÿ0-9]+$'), '');

  // Reinsere espaços perdidos na concatenação do extrator
  limpo = limpo.replaceAllMapped(
    RegExp(r'([a-zà-ÿ])([A-ZÀ-Ÿ])'),
    (m) => '${m[1]} ${m[2]}',
  );
  limpo = limpo.replaceAllMapped(
    RegExp(r'([A-Za-zÀ-ÿ])(\d)'),
    (m) => '${m[1]} ${m[2]}',
  );
  limpo = limpo.replaceAllMapped(
    RegExp(r'(\d)([A-Za-zÀ-ÿ])'),
    (m) => '${m[1]} ${m[2]}',
  );

  // Colapsa espaços múltiplos
  limpo = limpo.replaceAll(RegExp(r'\s{2,}'), ' ');

  return limpo.trim();
}

// ─── Extração principal ───

final _rePeriodoCompleto = RegExp(r'^\d{4}\.\d$');
final _rePeriodoSemDigito = RegExp(r'^\d{4}\.$');
final _reSoTracos = RegExp(r'^-+$');
final _reNomeTodoMaiusculo = RegExp(r'^[A-ZÀ-ÿ\s]+$');

/// Porte fiel de `extractDisciplinasFromPositions`.
List<DisciplinaExtraida> extrairDisciplinasPosicional(
  List<List<ItemPosicionado>> paginas,
) {
  final cols = _detectarColunas(paginas);

  // Classifica as linhas de todas as páginas
  final todasLinhas = <_LinhaClassificada>[];

  for (var pageIdx = 0; pageIdx < paginas.length; pageIdx++) {
    for (final (y, itens) in agruparItensEmLinhas(paginas[pageIdx])) {
      todasLinhas.add(_classificarLinha(y, pageIdx + 1, itens, cols));
    }
  }

  // Ordena: página crescente, Y crescente (topo→base no Syncfusion;
  // equivale ao "Y desc" do PDF.js, que tem origem embaixo)
  todasLinhas.sort((a, b) {
    if (a.page != b.page) return a.page.compareTo(b.page);
    return a.y.compareTo(b.y);
  });

  // Percorre as linhas e monta as disciplinas
  final disciplinas = <DisciplinaExtraida>[];

  for (var i = 0; i < todasLinhas.length; i++) {
    final linha = todasLinhas[i];

    if (linha.rowType != _TipoLinha.data) continue;

    // ─── Linha de dados de disciplina ───

    // Período
    var anoPeriodo = linha.period == '--' ? '' : linha.period;
    if (anoPeriodo.isNotEmpty && !_rePeriodoCompleto.hasMatch(anoPeriodo)) {
      // Tenta consertar período parcial "2022." → "2022.0"
      if (_rePeriodoSemDigito.hasMatch(anoPeriodo)) {
        anoPeriodo = '${anoPeriodo}0';
      }
    }

    final prefixo = linha.symbol;
    final codigo = linha.code;

    // Colunas de dados
    final chStr = linha.ch.replaceAll(RegExp(r'[^0-9]'), '');
    final cargaH = int.tryParse(chStr) ?? 0;
    final turma = linha.turma.replaceFirst(_reSoTracos, '--');
    final freqRaw = linha.freq.replaceAll(RegExp(r'\s'), '');
    final notaRaw = linha.nota.replaceAll(RegExp(r'\s'), '');
    final situacao = linha.situacao.replaceAll(RegExp(r'\s'), '');

    // Valida a situação
    if (!_reStatusValido.hasMatch(situacao)) {
      continue; // não é uma linha de disciplina de verdade
    }

    // Frequência e menção
    final frequencia =
        (freqRaw == '--' ||
            freqRaw == '-' ||
            freqRaw == '---' ||
            freqRaw.isEmpty)
        ? null
        : freqRaw;
    final mencao =
        (notaRaw == '---' ||
            notaRaw == '-' ||
            notaRaw == '--' ||
            notaRaw.isEmpty)
        ? '-'
        : notaRaw;

    // Conteúdo: separa professor e nome inline
    final contentSplit = _separarProfessorENome(linha.content);
    var professor = contentSplit.professor;
    var nome = contentSplit.name;

    // Procura o nome da disciplina nas linhas anteriores
    // (o nome aparece na linha acima da linha de dados)
    if (i > 0) {
      // Acumula as linhas name-only anteriores ainda não consumidas
      final nameRows = <String>[];
      var j = i - 1;
      while (j >= 0 &&
          (todasLinhas[j].rowType == _TipoLinha.nameOnly ||
              todasLinhas[j].rowType == _TipoLinha.continuation)) {
        if (todasLinhas[j].rowType == _TipoLinha.nameOnly) {
          nameRows.insert(0, todasLinhas[j].content);
        }
        j--;
      }

      if (nameRows.isNotEmpty) {
        final prevName = nameRows.join(' ');
        if (nome.isEmpty) {
          nome = prevName;
        } else {
          // Já temos nome do conteúdo — se o nome anterior parece um nome
          // real de disciplina (todo maiúsculo), ele vence
          if (_reNomeTodoMaiusculo.hasMatch(prevName) && prevName.length > 5) {
            nome = prevName;
          }
        }
        // Marca as linhas como consumidas
        for (
          var k = i - 1;
          k >= 0 &&
              (todasLinhas[k].rowType == _TipoLinha.nameOnly ||
                  todasLinhas[k].rowType == _TipoLinha.continuation);
          k--
        ) {
          todasLinhas[k].rowType = _TipoLinha.unknown; // consumida
        }
      }
    }

    // Procura continuação de professor nas linhas seguintes (ex.: "(30h)")
    for (var j = i + 1; j < todasLinhas.length; j++) {
      if (todasLinhas[j].rowType == _TipoLinha.continuation) {
        professor = professor.isNotEmpty
            ? '$professor ${todasLinhas[j].content}'
            : todasLinhas[j].content;
        todasLinhas[j].rowType = _TipoLinha.unknown; // consumida
      } else {
        break;
      }
    }

    // Limpeza final
    nome = limparNomeDisciplina(nome);
    professor = _limparNomeProfessor(professor);

    disciplinas.add(
      DisciplinaExtraida(
        tipoDado: 'Disciplina Regular',
        nome: nome,
        status: situacao,
        mencao: mencao,
        creditos: cargaH > 0 ? cargaH ~/ 15 : 0,
        codigo: codigo,
        cargaHoraria: cargaH,
        anoPeriodo: anoPeriodo,
        prefixo: prefixo,
        professor: professor,
        turma: turma,
        frequencia: frequencia,
      ),
    );
  }

  return disciplinas;
}
