import '../utils/json_utils.dart';

/// Uma matéria como registrada no histórico/fluxograma do aluno.
///
/// Vem de dentro do JSON `dados_users.fluxograma_atual` (chaves snake_case,
/// mesmo formato do site — ver factories do frontend Svelte). Todo parsing é
/// defensivo: campo ausente, nulo ou com tipo errado nunca estoura.
class DadosMateria {
  String codigoMateria;

  /// Nome como veio do histórico — necessário para matérias fora da matriz
  /// (módulo livre/eletivas), que não existem no courseData.
  String? nomeMateria;

  /// Menção do SIGAA: SS/MS/MM/MI/II/SR ou "-".
  String mencao;
  String professor;

  /// Status do SIGAA: APR/CUMP/DISP/MATR/REP/TRC — ou PLANEJADO (do app).
  String status;
  String? anoPeriodo;
  String? frequencia;
  String? tipoDado;
  String? turma;

  /// Créditos no histórico (fallback quando a matéria está fora da matriz).
  int? creditos;

  /// Inclusão manual do usuário (não veio do histórico oficial).
  bool isManual;

  /// Quando cumprida por equivalência: código da disciplina cursada de fato.
  String? codigoEquivalente;

  /// Quando cumprida por equivalência: nome da disciplina cursada de fato.
  String? nomeEquivalente;

  /// Nível (semestre) de destino escolhido pelo usuário.
  int? nivelDestino;

  /// Nível oficial da matriz (quando conhecido).
  int? nivel;

  DadosMateria({
    required this.codigoMateria,
    this.nomeMateria,
    this.mencao = '-',
    this.professor = '',
    this.status = '-',
    this.anoPeriodo,
    this.frequencia,
    this.tipoDado,
    this.turma,
    this.creditos,
    this.isManual = false,
    this.codigoEquivalente,
    this.nomeEquivalente,
    this.nivelDestino,
    this.nivel,
  });

  factory DadosMateria.fromJson(Map<String, dynamic> json) {
    return DadosMateria(
      codigoMateria: parseStringOr(
        json['codigo'] ?? json['codigo_materia'] ?? json['codigoMateria'],
      ),
      nomeMateria: parseStringOrNull(
        json['nome_materia'] ?? json['nome'] ?? json['nomeMateria'],
      ),
      mencao: parseStringOr(json['mencao'], '-'),
      professor: parseStringOr(json['professor']),
      status: parseStringOr(json['status'], '-'),
      anoPeriodo: parseStringOrNull(json['ano_periodo'] ?? json['anoPeriodo']),
      frequencia: parseStringOrNull(json['frequencia']),
      tipoDado: parseStringOrNull(json['tipo_dado'] ?? json['tipoDado']),
      turma: parseStringOrNull(json['turma']),
      creditos: parseIntOrNull(json['creditos']),
      isManual: parseBoolOr(json['is_manual'] ?? json['isManual']),
      codigoEquivalente: parseStringOrNull(
        json['codigo_equivalente'] ?? json['codigoEquivalente'],
      ),
      nomeEquivalente: parseStringOrNull(
        json['nome_equivalente'] ?? json['nomeEquivalente'],
      ),
      nivelDestino: parseIntOrNull(
        json['nivel_destino'] ?? json['nivelDestino'],
      ),
      nivel: parseIntOrNull(json['nivel'] ?? json['nivel_alocado']),
    );
  }

  String get _statusNormalizado => status.trim().toUpperCase();

  /// Já cursou (aprovada, cumprida ou dispensada).
  bool get isCursada {
    final s = _statusNormalizado;
    return s == 'APR' || s == 'CUMP' || s == 'DISP';
  }

  /// Aprovada — o status explícito do SIGAA prevalece sobre a menção
  /// (evita falso positivo de TRANC com menção residual). Menção só é usada
  /// como fallback legado quando o status vem vazio.
  bool get isAprovada {
    final s = _statusNormalizado;
    if (s == 'APR' || s == 'CUMP' || s == 'DISP') return true;
    if (s == 'TRANC' ||
        s == 'MATR' ||
        s == 'CANC' ||
        s == 'REP' ||
        s == 'REPF' ||
        s == 'REPMF') {
      return false;
    }
    final m = mencao.trim().toUpperCase();
    return m == 'SS' || m == 'MM' || m == 'MS';
  }

  /// Matriculado neste período (em curso).
  bool get isEmCurso => _statusNormalizado == 'MATR';
}

/// Optativa colocada no fluxograma pelo usuário (planejamento).
class OptativaPlanejadaRef {
  final String codigoMateria;
  final int semestre;

  const OptativaPlanejadaRef({
    required this.codigoMateria,
    required this.semestre,
  });

  static OptativaPlanejadaRef? fromJson(dynamic json) {
    final map = asMapOrNull(json);
    if (map == null) return null;
    final codigo = parseStringOr(
      map['codigo_materia'] ?? map['codigoMateria'],
    ).trim();
    if (codigo.isEmpty) return null;
    final semestre = parseIntOr(map['semestre'], 1);
    return OptativaPlanejadaRef(
      codigoMateria: codigo,
      semestre: semestre >= 1 ? semestre : 1,
    );
  }
}

/// O fluxograma do aluno como persistido em `dados_users.fluxograma_atual`.
///
/// Atenção: no banco a coluna é TEXT contendo JSON — use [fromDynamic] quando
/// o valor puder vir tanto como Map quanto como String JSON.
class DadosFluxogramaUser {
  String nomeCurso;
  String matrizCurricular;
  String matricula;
  int semestreAtual;
  String anoAtual;
  double ira;

  /// Texto do IRA como no histórico (ex.: "4,1234") — exibição fiel.
  String? iraTexto;
  int horasIntegralizadas;
  List<String> suspensoes;

  /// Matriz semestre × matérias.
  List<List<DadosMateria>> dadosFluxograma;

  /// Planejamento de optativas no fluxograma (semestre + código).
  List<OptativaPlanejadaRef> optativasPlanejadas;

  /// Versão do schema com que o upload gerou este dado.
  /// Null = upload antigo, anterior ao versionamento.
  int? schemaVersion;

  DadosFluxogramaUser({
    this.nomeCurso = '',
    this.matrizCurricular = '',
    this.matricula = '',
    this.semestreAtual = 0,
    this.anoAtual = '',
    this.ira = 0,
    this.iraTexto,
    this.horasIntegralizadas = 0,
    this.suspensoes = const [],
    this.dadosFluxograma = const [],
    this.optativasPlanejadas = const [],
    this.schemaVersion,
  });

  factory DadosFluxogramaUser.fromJson(Map<String, dynamic> json) {
    final semestres = <List<DadosMateria>>[];
    for (final semestre in asListOr(json['dados_fluxograma'])) {
      final materias = <DadosMateria>[];
      for (final materia in asListOr(semestre)) {
        final map = asMapOrNull(materia);
        if (map != null) materias.add(DadosMateria.fromJson(map));
      }
      semestres.add(materias);
    }

    final optativas = <OptativaPlanejadaRef>[];
    for (final item in asListOr(
      json['optativas_planejadas'] ?? json['optativasPlanejadas'],
    )) {
      final ref = OptativaPlanejadaRef.fromJson(item);
      if (ref != null) optativas.add(ref);
    }

    final iraTexto = parseStringOrNull(json['ira_texto'])?.trim();

    return DadosFluxogramaUser(
      nomeCurso: parseStringOr(json['nome_curso']),
      matrizCurricular: parseStringOr(json['matriz_curricular']),
      matricula: parseStringOr(json['matricula']),
      semestreAtual: parseIntOr(json['semestre_atual']),
      anoAtual: parseStringOr(json['ano_atual']),
      ira: parseDoubleOr(json['ira']),
      iraTexto: (iraTexto == null || iraTexto.isEmpty) ? null : iraTexto,
      horasIntegralizadas: parseIntOr(json['horas_integralizadas']),
      suspensoes: asListOr(
        json['suspensoes'],
      ).map((e) => e.toString()).toList(),
      dadosFluxograma: semestres,
      optativasPlanejadas: optativas,
      schemaVersion: parseIntOrNull(
        json['schema_version'] ?? json['schemaVersion'],
      ),
    );
  }

  /// Aceita tanto Map quanto String JSON (a coluna do banco é TEXT).
  static DadosFluxogramaUser? fromDynamic(dynamic value) {
    final map = decodeJsonMap(value);
    if (map == null) return null;
    return DadosFluxogramaUser.fromJson(map);
  }

  /// Todas as matérias do fluxograma, achatadas.
  Iterable<DadosMateria> get todasMaterias =>
      dadosFluxograma.expand((semestre) => semestre);
}

/// Usuário do NoFluxo (linha de `public.users` + fluxograma de `dados_users`).
class UserModel {
  final int idUser;

  /// UUID do Supabase Auth (coluna `auth_id`).
  final String? authId;
  final String email;
  final String nomeCompleto;
  DadosFluxogramaUser? dadosFluxograma;

  UserModel({
    required this.idUser,
    this.authId,
    required this.email,
    required this.nomeCompleto,
    this.dadosFluxograma,
  });

  /// Espera o shape da query `users.select('*, dados_users(*)')`.
  ///
  /// `dados_users` pode vir como lista (relação 1:N) ou como objeto único, e
  /// `fluxograma_atual` é TEXT com JSON — ambos os formatos são aceitos.
  factory UserModel.fromJson(Map<String, dynamic> json) {
    final user = UserModel(
      idUser: parseIntOr(json['id_user']),
      authId: parseStringOrNull(json['auth_id']),
      email: parseStringOr(json['email']),
      nomeCompleto: parseStringOr(json['nome_completo']),
    );

    final dadosUsers = json['dados_users'];
    Map<String, dynamic>? primeiraLinha;
    if (dadosUsers is List && dadosUsers.isNotEmpty) {
      primeiraLinha = asMapOrNull(dadosUsers.first);
    } else {
      primeiraLinha = asMapOrNull(dadosUsers);
    }

    if (primeiraLinha != null) {
      user.dadosFluxograma = DadosFluxogramaUser.fromDynamic(
        primeiraLinha['fluxograma_atual'],
      );
    }

    return user;
  }
}
