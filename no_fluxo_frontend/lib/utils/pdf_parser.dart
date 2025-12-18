/// Parser de PDF para histórico escolar da UnB
/// Extrai dados acadêmicos diretamente no frontend
library;

import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Modelo de dados para disciplina
class Disciplina {
  final String anoPeriodo;
  final String nome;
  final String codigo;
  final String status;
  final String? mencao;
  final String? turma;
  final int? cargaHoraria;
  final double? frequencia;
  final String? professor;
  final String tipoDado;

  Disciplina({
    required this.anoPeriodo,
    required this.nome,
    required this.codigo,
    required this.status,
    this.mencao,
    this.turma,
    this.cargaHoraria,
    this.frequencia,
    this.professor,
    this.tipoDado = 'Disciplina Regular',
  });

  Map<String, dynamic> toJson() => {
        'ano_periodo': anoPeriodo,
        'nome': nome,
        'codigo': codigo,
        'status': status,
        'mencao': mencao,
        'turma': turma,
        'carga_horaria': cargaHoraria,
        'frequencia': frequencia,
        'professor': professor,
        'tipo_dado': tipoDado,
      };
}

/// Modelo de dados para equivalência
class Equivalencia {
  final String codigoCumprido;
  final String nomeCumprido;
  final int cargaHorariaCumprida;
  final String codigoEquivalente;
  final String nomeEquivalente;
  final int cargaHorariaEquivalente;

  Equivalencia({
    required this.codigoCumprido,
    required this.nomeCumprido,
    required this.cargaHorariaCumprida,
    required this.codigoEquivalente,
    required this.nomeEquivalente,
    required this.cargaHorariaEquivalente,
  });

  Map<String, dynamic> toJson() => {
        'codigo_cumprido': codigoCumprido,
        'nome_cumprido': nomeCumprido,
        'carga_horaria_cumprida': cargaHorariaCumprida,
        'codigo_equivalente': codigoEquivalente,
        'nome_equivalente': nomeEquivalente,
        'carga_horaria_equivalente': cargaHorariaEquivalente,
      };
}

/// Resultado do parsing do PDF
class PdfParseResult {
  final String? curso;
  final String? matrizCurricular;
  final double? mediaPonderada;
  final double? ira;
  final String? semestreAtual;
  final int? numeroSemestre;
  final List<Disciplina> disciplinas;
  final List<Equivalencia> equivalencias;
  final List<String> suspensoes;
  final String fullText;

  PdfParseResult({
    this.curso,
    this.matrizCurricular,
    this.mediaPonderada,
    this.ira,
    this.semestreAtual,
    this.numeroSemestre,
    required this.disciplinas,
    required this.equivalencias,
    required this.suspensoes,
    required this.fullText,
  });

  Map<String, dynamic> toJson() => {
        'curso_extraido': curso,
        'matriz_curricular': matrizCurricular,
        'media_ponderada': mediaPonderada,
        'ira': ira,
        'semestre_atual': semestreAtual,
        'numero_semestre': numeroSemestre,
        'extracted_data': disciplinas.map((d) => d.toJson()).toList(),
        'equivalencias_pdf': equivalencias.map((e) => e.toJson()).toList(),
        'suspensoes': suspensoes,
        'full_text': fullText,
      };
}

/// Parser de PDF para histórico escolar
class PdfParser {
  /// Padrões Regex para extração de dados
  static final _padraoIra = RegExp(r'IRA[:\s]+(\d+[\.,]\d+)', caseSensitive: false);
  static final _padraoMp = RegExp(r'MP[:\s]+(\d+[\.,]\d+)', caseSensitive: false);
  static final _padraoCurriculo = RegExp(r'(\d{4}[\./]\d+(?:\s*-\s*\d{4}\.\d)?)', multiLine: true);
  static final _padraoCurso = RegExp(r'Curso[:\s]+([A-ZÀ-Ÿ\s/\\-]+?)(?:\s+Status:|$)', caseSensitive: false, multiLine: true);
  static final _padraoCursoAlt = RegExp(r'^([A-ZÀ-ÿ\s]+(?:DE\s+[A-ZÀ-ÿ\s]+)*)/[A-Z]+ - [A-ZÀ-ÿ\s]+ - [A-ZÀ-ÿ]+', multiLine: true, caseSensitive: false);
  
  /// Padrões para processamento linha por linha (formato PyMuPDF estruturado)
  /// Flexíveis para aceitar variações entre diferentes cursos/departamentos da UnB
  static final _padraoNomeDisciplina = RegExp(
    r'^([A-ZÀ-ÿ][A-ZÀ-ÿ\s0-9\-\/\(\)]+(?:DE\s+[A-ZÀ-ÿ\s0-9\-\/\(\)]*)*(?:\s+[A-ZÀ-ÿ\s0-9\-\/\(\)]*)*)\s*$',
    multiLine: true,
    caseSensitive: false,
  );
  static final _padraoAnoPeriodo = RegExp(r'^(\d{4}\.\d)$', multiLine: true);
  /// Códigos podem variar: CIC123, MAT456, FIS1234, ENG0001, etc.
  static final _padraoCodigoDisciplina = RegExp(r'^([A-Z]{2,}\d{3,})$', multiLine: true);
  /// Todos os status possíveis do SIGAA
  static final _padraoSituacao = RegExp(r'^(MATR|APR|REP|REPF|REPMF|CANC|DISP|TRANC|TRANCF|CUMP)$', multiLine: true);
  static final _padraoMencao = RegExp(r'^(SS|MS|MM|MI|II|SR|\-)$', multiLine: true);
  /// Turmas: A, B, 01, 02, A1, etc.
  static final _padraoTurma = RegExp(r'^([A-Z0-9]{1,4})$', multiLine: true);
  /// Carga horária: 15, 30, 45, 60, 90, 120, etc.
  static final _padraoCargaHoraria = RegExp(r'^(\d{1,4})$', multiLine: true);
  static final _padraoFrequencia = RegExp(r'^(\d{1,3}[,\.]\d+|--|\d{1,3})$', multiLine: true);
  static final _padraoSimbolos = RegExp(r'^([*&#e@§%]+)\s*$', multiLine: true);

  /// Padrão para equivalências
  static final _padraoEquivalencias = RegExp(
    r'Cumpriu\s+([A-Z]{2,}\d{3,})\s*-\s*([A-ZÀ-Ÿ\s0-9]+?)\s*\((\d+)h\)\s*através\s*de\s*([A-Z]{2,}\d{3,})\s*-\s*([A-ZÀ-Ÿ\s0-9]+?)\s*\((\d+)h\)',
    multiLine: true,
    caseSensitive: false,
  );

  /// Padrão para suspensões
  static final _padraoSuspensoes = RegExp(
    r'Suspensões:\s*\n((?:\d{4}\.\d(?:\s*,\s*\d{4}\.\d)*)?)',
    multiLine: true,
    caseSensitive: false,
  );

  /// Padrão para disciplinas pendentes
  static final _padraoPendentesSigaa = RegExp(
    r'^\s+([A-ZÀ-Ÿ\sÇÃÕÁÉÍÓÚÂÊÎÔÛ0-9]+?)\s+(\d+)\s+h\s+([A-Z]{2,}\d{3,})(?:\s+(Matriculado|Matriculado em Equivalente))?$',
    multiLine: true,
    caseSensitive: false,
  );

  /// Padrão para professor
  static final _padraoProfessor = RegExp(
    r'(?:Dr\.|Dra\.|MSc\.|Prof\.|Professor|Professora)?\s*([A-ZÀ-ÿ\s\.]+?)\s*\((\d+)h\)',
    caseSensitive: false,
  );

  /// Faz o parsing de um arquivo PDF
  /// 
  /// [pdfBytes] - Bytes do arquivo PDF
  /// [matricula] - Matrícula do aluno (opcional)
  /// 
  /// Retorna [PdfParseResult] com os dados extraídos
  static Future<PdfParseResult> parsePdf(Uint8List pdfBytes, {String? matricula}) async {
    try {
      // Carrega o documento PDF
      final PdfDocument document = PdfDocument(inputBytes: pdfBytes);
      
      // Extrai texto de todas as páginas
      final PdfTextExtractor extractor = PdfTextExtractor(document);
      String fullText = '';
      
      for (int i = 0; i < document.pages.count; i++) {
        final String pageText = extractor.extractText(startPageIndex: i, endPageIndex: i);
        fullText += pageText + '\n';
      }
      
      // Fecha o documento
      document.dispose();
      
      // Extrai dados acadêmicos
      final curso = _extrairCurso(fullText);
      final matrizCurricular = _extrairMatrizCurricular(fullText);
      final mediaPonderada = _extrairMp(fullText);
      final ira = _extrairIra(fullText);
      final disciplinas = _extrairDisciplinas(fullText);
      final equivalencias = _extrairEquivalencias(fullText);
      final suspensoes = _extrairSuspensoes(fullText);
      final semestreAtual = _extrairSemestreAtual(disciplinas);
      final numeroSemestre = _calcularNumeroSemestre(disciplinas);
      
      return PdfParseResult(
        curso: curso,
        matrizCurricular: matrizCurricular,
        mediaPonderada: mediaPonderada,
        ira: ira,
        semestreAtual: semestreAtual,
        numeroSemestre: numeroSemestre,
        disciplinas: disciplinas,
        equivalencias: equivalencias,
        suspensoes: suspensoes,
        fullText: fullText,
      );
    } catch (e) {
      throw Exception('Erro ao processar PDF: $e');
    }
  }

  /// Extrai o nome do curso
  /// Suporta todos os formatos do SIGAA da UnB
  static String? _extrairCurso(String texto) {
    // Tenta padrão alternativo primeiro (formato completo)
    final matchAlt = _padraoCursoAlt.firstMatch(texto);
    if (matchAlt != null) {
      return matchAlt.group(1)?.trim();
    }
    
    // Tenta padrão original com label "Curso:"
    final match = _padraoCurso.firstMatch(texto);
    if (match != null) {
      String curso = match.group(1)?.trim() ?? '';
      // Remove sufixos desnecessários (campus, turno, habilitação)
      curso = curso.split('/')[0].split('-')[0].trim();
      // Remove espaços extras
      curso = curso.replaceAll(RegExp(r'\s+'), ' ');
      return curso;
    }
    
    // Fallback: busca por padrões conhecidos de curso
    final cursosFallback = RegExp(r'\b([A-ZÀ-ÿ]{2,}(?:\s+[A-ZÀ-ÿ]{2,}){1,5})\b(?=\s*\/)');
    final matchFallback = cursosFallback.firstMatch(texto);
    if (matchFallback != null) {
      print('[CURSO] Extraído via fallback: ${matchFallback.group(1)}');
      return matchFallback.group(1)?.trim();
    }
    
    print('[AVISO] Curso não encontrado no PDF');
    return null;
  }

  /// Extrai a matriz curricular
  static String? _extrairMatrizCurricular(String texto) {
    final match = _padraoCurriculo.firstMatch(texto);
    if (match != null) {
      return match.group(1)?.replaceAll('/', '.');
    }
    return null;
  }

  /// Extrai a média ponderada (MP)
  static double? _extrairMp(String texto) {
    final match = _padraoMp.firstMatch(texto);
    if (match != null) {
      final mpStr = match.group(1)?.replaceAll(',', '.');
      return double.tryParse(mpStr ?? '');
    }
    return null;
  }

  /// Extrai o IRA
  static double? _extrairIra(String texto) {
    final match = _padraoIra.firstMatch(texto);
    if (match != null) {
      final iraStr = match.group(1)?.replaceAll(',', '.');
      return double.tryParse(iraStr ?? '');
    }
    return null;
  }

  /// Extrai as disciplinas do histórico
  /// FORMATO REAL DO PDF (Syncfusion extrai cada campo em linha separada):
  /// Linha N:   "2023.2"
  /// Linha N+1: "CÁLCULO 1Dr. RICARDO FRAGELLI (90h)"
  /// Linha N+2: "24"  (turma)
  /// Linha N+3: "APR" (status)
  /// Linha N+4: "MAT0025" (código)
  /// Linha N+5: "90" (carga horária)
  /// Linha N+6: "95,0" (frequência)
  /// Linha N+7: "MS" (menção)
  static List<Disciplina> _extrairDisciplinas(String texto) {
    final List<Disciplina> disciplinas = [];
    final linhas = texto.split('\n').map((l) => l.trim()).toList();
    
    print('[DEBUG] Processando ${linhas.length} linhas para extrair disciplinas...');
    
    // Padrões
    final regexAnoPeriodo = RegExp(r'^(\d{4}\.\d)$');
    final regexNomeProfessor = RegExp(r'^(.+?)((?:Dr\.|Dra\.|Prof\.|MSc\.).+\(\d+h\))$');
    final regexTurma = RegExp(r'^\d{1,2}$');
    final regexStatus = RegExp(r'^(APR|REP|REPF|REPMF|CANC|DISP|TRANC|TRANCF|MATR|CURS)$');
    final regexCodigo = RegExp(r'^([A-Z]{2,}\d{3,})$');
    final regexCargaHoraria = RegExp(r'^\d{2,3}$');
    final regexFrequencia = RegExp(r'^(\d{1,3}[,.]?\d*|--|\d{1,3})$');
    final regexMencao = RegExp(r'^(SS|MS|MM|MI|II|SR|\-)$');
    final regexMarcador = RegExp(r'^[#*e@]+$');
    
    int i = 0;
    int encontradas = 0;
    int ignoradas = 0;
    
    while (i < linhas.length - 7) { // Precisa de pelo menos 8 linhas
      final linha = linhas[i];
      
      // Busca por ano/período (início de disciplina)
      if (regexAnoPeriodo.hasMatch(linha)) {
        final anoPeriodo = linha;
        
        // Pula linhas vazias ou marcadores
        int offset = 1;
        while (i + offset < linhas.length && 
               (linhas[i + offset].isEmpty || regexMarcador.hasMatch(linhas[i + offset]))) {
          offset++;
        }
        
        // Próxima linha deve ter nome + professor
        if (i + offset >= linhas.length) {
          i++;
          continue;
        }
        
        final linhaNomeProfessor = linhas[i + offset];
        final matchNomeProf = regexNomeProfessor.firstMatch(linhaNomeProfessor);
        
        if (matchNomeProf == null) {
          i++;
          continue;
        }
        
        final nomeDisciplina = matchNomeProf.group(1)!.trim();
        final professor = matchNomeProf.group(2)!.trim();
        
        // Pula ENADE e similares
        if (nomeDisciplina.contains('ENADE') || 
            nomeDisciplina.contains('INGRESSANTE') ||
            nomeDisciplina.contains('PROJETO PEDAGÓGICO')) {
          i++;
          continue;
        }
        
        offset++;
        
        // Busca turma, status, código, carga, frequência, menção nas próximas linhas
        String? turma;
        String? status;
        String? codigo;
        int? cargaHoraria;
        double? frequencia;
        String? mencao;
        
        for (int j = 0; j < 10 && i + offset + j < linhas.length; j++) {
          final proxLinha = linhas[i + offset + j];
          
          if (proxLinha.isEmpty || regexMarcador.hasMatch(proxLinha)) continue;
          
          if (turma == null && regexTurma.hasMatch(proxLinha)) {
            turma = proxLinha;
          } else if (status == null && regexStatus.hasMatch(proxLinha)) {
            status = proxLinha;
          } else if (codigo == null && regexCodigo.hasMatch(proxLinha)) {
            codigo = proxLinha;
          } else if (cargaHoraria == null && regexCargaHoraria.hasMatch(proxLinha)) {
            cargaHoraria = int.tryParse(proxLinha);
          } else if (frequencia == null && regexFrequencia.hasMatch(proxLinha)) {
            frequencia = proxLinha == '--' ? null : double.tryParse(proxLinha.replaceAll(',', '.'));
          } else if (mencao == null && regexMencao.hasMatch(proxLinha)) {
            mencao = proxLinha;
            break; // Menção é o último campo
          }
        }
        
        // Valida se encontrou campos essenciais
        if (codigo != null && status != null && mencao != null) {
          // CORREÇÃO: Não ignora mais aqui - adiciona todas as ocorrências
          // A filtragem de menções problemáticas será feita ao remover duplicatas
          
          disciplinas.add(Disciplina(
            anoPeriodo: anoPeriodo,
            nome: _limparNomeDisciplina(nomeDisciplina),
            codigo: codigo,
            status: status,
            mencao: mencao == '-' ? null : mencao,
            turma: turma,
            cargaHoraria: cargaHoraria,
            frequencia: frequencia,
            professor: professor,
            tipoDado: 'Disciplina Regular',
          ));
          
          encontradas++;
          final nomeSubstr = nomeDisciplina.length > 40 ? nomeDisciplina.substring(0, 40) : nomeDisciplina;
          
          // Log diferente para menções problemáticas
          if (['II', 'MI', 'SR'].contains(mencao)) {
            print('  ⚠ $codigo - $nomeSubstr... ($status/$mencao) [será filtrado se houver versão melhor]');
          } else {
            print('  ✓ $codigo - $nomeSubstr... ($status/$mencao)');
          }
        }
      }
      
      i++;
    }
    
    print('[RESULTADO] $encontradas disciplinas extraídas, $ignoradas ignoradas (menção problemática)');
    
    // Extrair disciplinas pendentes (que NÃO foram extraídas no loop principal)
    final codigosJaExtraidos = disciplinas.map((d) => d.codigo).toSet();
    final matchesPendentes = _padraoPendentesSigaa.allMatches(texto);
    
    for (final match in matchesPendentes) {
      try {
        final nome = match.group(1)?.trim() ?? '';
        final cargaH = match.group(2) ?? '';
        final codigo = match.group(3) ?? '';
        final statusMatricula = match.group(4);
        
        // CORREÇÃO: Pula se já foi extraída (evita duplicação de MATR)
        if (codigosJaExtraidos.contains(codigo)) {
          continue;
        }
        
        final status = statusMatricula != null ? 'MATR' : 'PENDENTE';
        
        disciplinas.add(Disciplina(
          anoPeriodo: '',
          nome: _limparNomeDisciplina(nome),
          codigo: codigo,
          status: status,
          mencao: '-',
          cargaHoraria: int.tryParse(cargaH),
          tipoDado: 'Disciplina Pendente',
        ));
        
        print('  -> Pendente: $codigo - ${nome.substring(0, nome.length < 30 ? nome.length : 30)}... (Status: $status)');
      } catch (e) {
        // Ignora erros
        continue;
      }
    }
    
    // CORREÇÃO: Remove duplicatas mantendo a melhor ocorrência
    // Critérios de prioridade:
    // 1. Menção boa (APR/MS/MM/SS) > Menção ruim (MI/II/SR)
    // 2. Mais recente (maior ano/período)
    // 3. Status cursado > PENDENTE
    final disciplinasUnicas = <String, Disciplina>{};
    int removidasMencaoRuim = 0;
    
    for (final disc in disciplinas) {
      final codigo = disc.codigo;
      
      // Se não existe ainda, adiciona
      if (!disciplinasUnicas.containsKey(codigo)) {
        disciplinasUnicas[codigo] = disc;
        continue;
      }
      
      // Se já existe, decide qual manter
      final existente = disciplinasUnicas[codigo]!;
      final mencaoAtual = disc.mencao ?? '-';
      final mencaoExistente = existente.mencao ?? '-';
      
      final mencoesBoas = ['SS', 'MS', 'MM', '-'];
      final mencoesRuins = ['MI', 'II', 'SR'];
      
      final atualBoa = mencoesBoas.contains(mencaoAtual);
      final existenteBoa = mencoesBoas.contains(mencaoExistente);
      final atualRuim = mencoesRuins.contains(mencaoAtual);
      final existenteRuim = mencoesRuins.contains(mencaoExistente);
      
      bool substituir = false;
      String motivo = '';
      
      // PRIORIDADE 1: Menção boa sempre ganha de menção ruim
      if (atualBoa && existenteRuim) {
        substituir = true;
        motivo = 'menção melhor (${disc.status}/$mencaoAtual vs ${existente.status}/$mencaoExistente)';
        removidasMencaoRuim++;
      } else if (atualRuim && existenteBoa) {
        substituir = false;
        motivo = 'mantém menção melhor (${existente.status}/$mencaoExistente vs ${disc.status}/$mencaoAtual)';
        removidasMencaoRuim++;
      }
      // PRIORIDADE 2: Se ambas têm menções do mesmo tipo, compara período
      else {
        final anoAtual = disc.anoPeriodo;
        final anoExistente = existente.anoPeriodo;
        
        if (anoAtual.isNotEmpty && anoExistente.isNotEmpty) {
          final comparacao = _compararPeriodos(anoAtual, anoExistente);
          if (comparacao > 0) {
            substituir = true;
            motivo = 'mais recente ($anoAtual vs $anoExistente)';
          } else if (comparacao < 0) {
            motivo = 'mantém mais recente ($anoExistente vs $anoAtual)';
          }
        } else if (anoAtual.isNotEmpty && anoExistente.isEmpty) {
          substituir = true;
          motivo = 'tem período válido';
        } else if (existente.status == 'PENDENTE' && disc.status != 'PENDENTE') {
          substituir = true;
          motivo = 'cursada vs pendente';
        }
      }
      
      if (substituir) {
        print('  [DUPLICATA] $codigo - Substituindo por ${disc.anoPeriodo} (${disc.status}/$mencaoAtual) - $motivo');
        disciplinasUnicas[codigo] = disc;
      } else if (motivo.isNotEmpty) {
        print('  [DUPLICATA] $codigo - $motivo');
      }
    }
    
    final disciplinasFinais = disciplinasUnicas.values.toList();
    print('[FINAL] ${disciplinasFinais.length} disciplinas únicas (removidas ${disciplinas.length - disciplinasFinais.length} duplicatas, incluindo $removidasMencaoRuim com menção ruim)');
    
    return disciplinasFinais;
  }

  /// Compara dois períodos no formato "YYYY.S" (ex: "2023.2")
  /// Retorna: -1 se periodo1 < periodo2, 0 se iguais, 1 se periodo1 > periodo2
  static int _compararPeriodos(String periodo1, String periodo2) {
    try {
      // Formato: "2023.2" -> [2023, 2]
      final partes1 = periodo1.split('.');
      final partes2 = periodo2.split('.');
      
      if (partes1.length != 2 || partes2.length != 2) {
        return 0; // Formato inválido, considera iguais
      }
      
      final ano1 = int.parse(partes1[0]);
      final ano2 = int.parse(partes2[0]);
      final semestre1 = int.parse(partes1[1]);
      final semestre2 = int.parse(partes2[1]);
      
      // Compara anos
      if (ano1 != ano2) {
        return ano1.compareTo(ano2);
      }
      
      // Se anos iguais, compara semestres
      return semestre1.compareTo(semestre2);
    } catch (e) {
      return 0; // Em caso de erro, considera iguais
    }
  }

  /// Extrai as equivalências
  static List<Equivalencia> _extrairEquivalencias(String texto) {
    final List<Equivalencia> equivalencias = [];
    
    final matches = _padraoEquivalencias.allMatches(texto);
    
    for (final match in matches) {
      try {
        equivalencias.add(Equivalencia(
          codigoCumprido: match.group(1) ?? '',
          nomeCumprido: match.group(2)?.trim() ?? '',
          cargaHorariaCumprida: int.tryParse(match.group(3) ?? '') ?? 0,
          codigoEquivalente: match.group(4) ?? '',
          nomeEquivalente: match.group(5)?.trim() ?? '',
          cargaHorariaEquivalente: int.tryParse(match.group(6) ?? '') ?? 0,
        ));
      } catch (e) {
        continue;
      }
    }
    
    return equivalencias;
  }

  /// Extrai as suspensões
  static List<String> _extrairSuspensoes(String texto) {
    final match = _padraoSuspensoes.firstMatch(texto);
    if (match != null) {
      final suspensoesStr = match.group(1);
      if (suspensoesStr != null && suspensoesStr.isNotEmpty) {
        return suspensoesStr
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }
    }
    return [];
  }

  /// Extrai o semestre atual baseado em disciplinas com status MATR
  static String? _extrairSemestreAtual(List<Disciplina> disciplinas) {
    final matriculadas = disciplinas
        .where((d) => d.status == 'MATR')
        .map((d) => d.anoPeriodo)
        .toList();
    
    if (matriculadas.isEmpty) return null;
    
    // Retorna o semestre mais recente
    matriculadas.sort((a, b) {
      final aNum = double.tryParse(a) ?? 0;
      final bNum = double.tryParse(b) ?? 0;
      return bNum.compareTo(aNum);
    });
    
    return matriculadas.first;
  }

  /// Calcula o número do semestre
  static int? _calcularNumeroSemestre(List<Disciplina> disciplinas) {
    // Conta semestres únicos
    final semestres = disciplinas
        .map((d) => d.anoPeriodo)
        .toSet()
        .toList();
    
    semestres.sort((a, b) {
      final aNum = double.tryParse(a) ?? 0;
      final bNum = double.tryParse(b) ?? 0;
      return aNum.compareTo(bNum);
    });
    
    return semestres.length;
  }

  /// Limpa o nome da disciplina removendo padrões desnecessários
  static String _limparNomeDisciplina(String nome) {
    // Remove padrões de período
    nome = nome.replaceAll(RegExp(r'^\d{4}\.\d\s*'), '');
    // Remove caracteres especiais do início e fim
    nome = nome.replaceAll(RegExp(r'^[^\w\s]+|[^\w\s]+$'), '');
    // Remove espaços extras
    nome = nome.replaceAll(RegExp(r'\s+'), ' ').trim();
    return nome;
  }
}
