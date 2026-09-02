import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_fluxo_app/core/models/curso_model.dart';
import 'package:no_fluxo_app/core/models/materia_model.dart';
import 'package:no_fluxo_app/core/models/user_model.dart';
import 'package:no_fluxo_app/core/services/auth_service.dart';
import 'package:no_fluxo_app/features/fluxograma/data/fluxograma_repository.dart';
import 'package:no_fluxo_app/features/fluxograma/ui/fluxograma_screen.dart';

// ── Fakes ────────────────────────────────────────────────────────────────────

/// Repositório fake: devolve fixtures sem tocar no Supabase.
class RepositorioFake implements FluxogramaRepository {
  RepositorioFake({
    this.cursos = const [],
    this.matrizes = const [],
    this.curso,
  });

  /// Mutável: os testes simulam o RLS liberando cursos após o login.
  List<CursoResumo> cursos;
  final List<MatrizResumo> matrizes;
  final CursoModel? curso;

  @override
  Future<List<CursoResumo>> buscarCursos() async => cursos;

  @override
  Future<List<MatrizResumo>> buscarMatrizes(int idCurso) async => matrizes;

  @override
  Future<MatrizResumo?> buscarMatrizPorCurriculo(
    String curriculoCompleto,
  ) async => matrizes.isEmpty ? null : matrizes.first;

  @override
  Future<CursoModel> buscarCursoDaMatriz(MatrizResumo matriz) async {
    final resultado = curso;
    if (resultado == null) throw Exception('sem curso no fake');
    return resultado;
  }
}

/// Auth fake: entrega um estado fixo sem inicializar o Supabase.
class AuthFake extends AuthNotifier {
  AuthFake(this._estado);

  final AuthState _estado;

  @override
  Future<AuthState> build() async => _estado;

  /// Simula uma transição de auth (ex.: visitante → logado).
  void emitir(AuthState novo) => state = AsyncData(novo);
}

// ── Fixtures ─────────────────────────────────────────────────────────────────

MateriaModel _materia(
  String codigo,
  String nome, {
  required int id,
  int nivel = 1,
}) {
  return MateriaModel(
    ementa: 'Ementa de $nome.',
    idMateria: id,
    nomeMateria: nome,
    codigoMateria: codigo,
    nivel: nivel,
    creditos: 4,
  );
}

CursoModel _cursoFixture() {
  final materias = [
    _materia('FGA0158', 'CÁLCULO 1', id: 1, nivel: 1),
    _materia('FGA0161', 'CÁLCULO 2', id: 2, nivel: 2),
  ];
  final curso = CursoModel(
    nomeCurso: 'ENGENHARIA DE SOFTWARE',
    matrizCurricular: '6360/2',
    idCurso: 10,
    totalCreditos: null,
    classificacao: '',
    tipoCurso: '',
    materias: materias,
    semestres: 2,
    preRequisitos: [
      PreRequisitoModel(
        idPreRequisito: 1,
        idMateria: 2,
        idMateriaRequisito: 1,
        codigoMateriaRequisito: 'FGA0158',
        nomeMateriaRequisito: 'CÁLCULO 1',
      ),
    ],
  );
  curso.populatePrerequisites();
  return curso;
}

const _matrizFixture = MatrizResumo(
  idMatriz: 5,
  idCurso: 10,
  curriculoCompleto: '6360/2',
);

UserModel _usuarioComHistorico() {
  return UserModel(
    idUser: 1,
    email: 'aluno@unb.br',
    nomeCompleto: 'Aluno Teste',
    dadosFluxograma: DadosFluxogramaUser(
      nomeCurso: 'ENGENHARIA DE SOFTWARE',
      matrizCurricular: '6360/2',
      dadosFluxograma: [
        [DadosMateria(codigoMateria: 'FGA0158', status: 'APR', mencao: 'MS')],
      ],
    ),
  );
}

Widget _app({
  required FluxogramaRepository repositorio,
  required AuthState auth,
}) {
  return ProviderScope(
    overrides: [
      fluxogramaRepositoryProvider.overrideWithValue(repositorio),
      authProvider.overrideWith(() => AuthFake(auth)),
    ],
    child: const MaterialApp(home: FluxogramaScreen()),
  );
}

// ── Testes ───────────────────────────────────────────────────────────────────

void main() {
  testWidgets('visitante vê o seletor e abre o fluxograma genérico', (
    tester,
  ) async {
    final repositorio = RepositorioFake(
      cursos: const [
        CursoResumo(idCurso: 10, nomeCurso: 'ENGENHARIA DE SOFTWARE'),
        CursoResumo(idCurso: 11, nomeCurso: 'ENGENHARIA AEROESPACIAL'),
      ],
      matrizes: const [_matrizFixture],
      curso: _cursoFixture(),
    );

    await tester.pumpWidget(
      _app(repositorio: repositorio, auth: const AuthState.anonymous()),
    );
    await tester.pumpAndSettle();

    // Seletor com os cursos disponíveis.
    expect(find.text('ENGENHARIA DE SOFTWARE'), findsOneWidget);
    expect(find.text('ENGENHARIA AEROESPACIAL'), findsOneWidget);

    // Escolhe um curso → fluxograma genérico da matriz.
    await tester.tap(find.text('ENGENHARIA DE SOFTWARE'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Fluxograma genérico'), findsOneWidget);
    expect(find.text('FGA0158'), findsOneWidget);
    expect(find.text('FGA0161'), findsOneWidget);
    expect(find.text('1º semestre'), findsOneWidget);
    expect(find.text('2º semestre'), findsOneWidget);
  });

  testWidgets('aluno logado vê progresso e cards por status', (tester) async {
    final repositorio = RepositorioFake(
      matrizes: const [_matrizFixture],
      curso: _cursoFixture(),
    );

    await tester.pumpWidget(
      _app(
        repositorio: repositorio,
        auth: AuthState.loggedIn(_usuarioComHistorico()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ENGENHARIA DE SOFTWARE'), findsOneWidget);
    // 1 de 2 obrigatórias aprovadas = 50%.
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('1 de 2 obrigatórias concluídas'), findsOneWidget);
    expect(find.text('FGA0158'), findsOneWidget);
    expect(find.text('FGA0161'), findsOneWidget);
  });

  testWidgets('tocar num card abre o sheet com detalhes e "Ver turmas"', (
    tester,
  ) async {
    final repositorio = RepositorioFake(
      matrizes: const [_matrizFixture],
      curso: _cursoFixture(),
    );

    await tester.pumpWidget(
      _app(
        repositorio: repositorio,
        auth: AuthState.loggedIn(_usuarioComHistorico()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('FGA0161'));
    await tester.pumpAndSettle();

    // Sheet aberto com ementa, status e pré-requisitos.
    expect(find.text('Ementa de CÁLCULO 2.'), findsOneWidget);
    expect(find.text('Ementa'), findsOneWidget);
    expect(find.text('Pré-requisitos'), findsOneWidget);
    expect(find.text('Disponível'), findsWidgets);
    expect(find.text('Ver turmas'), findsOneWidget);
  });

  testWidgets('seletor vazio mostra empty state e "Tentar novamente" refaz', (
    tester,
  ) async {
    final repositorio = RepositorioFake(
      cursos: const [],
      matrizes: const [_matrizFixture],
      curso: _cursoFixture(),
    );

    await tester.pumpWidget(
      _app(repositorio: repositorio, auth: const AuthState.anonymous()),
    );
    await tester.pumpAndSettle();

    // Nada de tela em branco: estado explicativo + retry.
    expect(
      find.textContaining('Não foi possível carregar os cursos'),
      findsOneWidget,
    );
    expect(find.text('Tentar novamente'), findsOneWidget);

    // A conexão voltou (ou as policies anon foram aplicadas): retry recarrega.
    repositorio.cursos = const [
      CursoResumo(idCurso: 10, nomeCurso: 'ENGENHARIA DE SOFTWARE'),
    ];
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(find.text('ENGENHARIA DE SOFTWARE'), findsOneWidget);
  });

  testWidgets('login invalida o cache vazio de cursos do visitante', (
    tester,
  ) async {
    final repositorio = RepositorioFake(cursos: const []);
    final authFake = AuthFake(const AuthState.anonymous());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fluxogramaRepositoryProvider.overrideWithValue(repositorio),
          authProvider.overrideWith(() => authFake),
        ],
        child: const MaterialApp(home: FluxogramaScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Não foi possível carregar os cursos'),
      findsOneWidget,
    );

    // Depois do login o RLS libera a leitura — o provider deve refazer a
    // query sozinho (observa o status de auth), sem reiniciar o app.
    repositorio.cursos = const [
      CursoResumo(idCurso: 10, nomeCurso: 'ENGENHARIA DE SOFTWARE'),
    ];
    authFake.emitir(const AuthState.loggedInSemPerfil());
    await tester.pumpAndSettle();

    expect(find.text('ENGENHARIA DE SOFTWARE'), findsOneWidget);
  });

  testWidgets('"Trocar curso" tem volta: ação restaura o meu fluxograma', (
    tester,
  ) async {
    final repositorio = RepositorioFake(
      cursos: const [
        CursoResumo(idCurso: 10, nomeCurso: 'ENGENHARIA DE SOFTWARE'),
      ],
      matrizes: const [_matrizFixture],
      curso: _cursoFixture(),
    );

    await tester.pumpWidget(
      _app(
        repositorio: repositorio,
        auth: AuthState.loggedIn(_usuarioComHistorico()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('FGA0158'), findsOneWidget);

    // Trocar curso: entra no seletor…
    await tester.tap(find.byIcon(Icons.swap_horiz));
    await tester.pumpAndSettle();
    expect(
      find.text('Escolha um curso para ver o fluxograma da matriz.'),
      findsOneWidget,
    );

    // …e a ação de desfazer devolve a visão personalizada sem reiniciar.
    await tester.tap(find.byIcon(Icons.undo));
    await tester.pumpAndSettle();
    expect(find.text('FGA0158'), findsOneWidget);
  });
}
