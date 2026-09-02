import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_fluxo_app/core/models/turma_model.dart';
import 'package:no_fluxo_app/core/models/user_model.dart';
import 'package:no_fluxo_app/core/services/auth_service.dart';
import 'package:no_fluxo_app/features/grade/data/aula_notification_scheduler.dart';
import 'package:no_fluxo_app/features/grade/data/grade_repository.dart';
import 'package:no_fluxo_app/features/grade/domain/grade_builder.dart';
import 'package:no_fluxo_app/features/grade/ui/grade_screen.dart';

// ── Fakes ────────────────────────────────────────────────────────────────────

/// Auth fake: entrega o estado desejado sem tocar no Supabase.
class _AuthNotifierFake extends AuthNotifier {
  final AuthState estado;

  _AuthNotifierFake(this.estado);

  @override
  Future<AuthState> build() async => estado;
}

/// Repositório fake: grade em memória.
class _GradeRepositoryFake implements GradeRepository {
  List<TurmaGrade> turmas;

  _GradeRepositoryFake(this.turmas);

  @override
  Future<List<TurmaGrade>> carregarGrade({
    DadosFluxogramaUser? dados,
    required int idUser,
  }) async => turmas;

  @override
  Future<void> adicionarTurmaManual({
    required int idUser,
    required TurmaModel turma,
  }) async {
    turmas = [...turmas, TurmaGrade(turma: turma, manual: true)];
  }

  @override
  Future<void> removerTurmaManual({
    required int idUser,
    required int idTurmas,
  }) async {
    turmas = turmas.where((t) => t.turma.idTurmas != idTurmas).toList();
  }

  @override
  Future<List<MateriaBusca>> buscarMaterias(String query) async => const [];

  @override
  Future<List<TurmaModel>> turmasDaMateria(int idMateria) async => const [];
}

/// Agendador fake: nada de plugin nem de shared_preferences.
class _SchedulerFake extends AulaNotificationScheduler {
  int sincronizacoes = 0;

  @override
  Future<ConfigNotificacaoAulas> carregarConfig() async =>
      const ConfigNotificacaoAulas();

  @override
  Future<void> salvarConfig(ConfigNotificacaoAulas config) async {}

  @override
  Future<bool> init() async => true;

  @override
  Future<void> sincronizar(List<TurmaGrade> turmas, {DateTime? now}) async {
    sincronizacoes++;
  }
}

// ── Fixtures ─────────────────────────────────────────────────────────────────

TurmaModel _turma({
  required int id,
  required String codigo,
  String? horario,
  String nome = 'Matéria',
  String? local,
}) {
  return TurmaModel(
    idTurmas: id,
    idMateria: id * 10,
    turma: '01',
    horario: horario,
    local: local,
    anoPeriodo: '2026.1',
    codigoMateria: codigo,
    nomeMateria: nome,
  );
}

AuthState _logado() => AuthState.loggedIn(
  UserModel(idUser: 42, email: 'aluno@unb.br', nomeCompleto: 'Aluno Teste'),
);

Widget _app({
  required AuthState auth,
  required GradeRepository repo,
  required AulaNotificationScheduler scheduler,
}) {
  return ProviderScope(
    overrides: [
      authProvider.overrideWith(() => _AuthNotifierFake(auth)),
      gradeRepositoryProvider.overrideWithValue(repo),
      aulaNotificationSchedulerProvider.overrideWithValue(scheduler),
    ],
    child: const MaterialApp(home: GradeScreen()),
  );
}

void main() {
  testWidgets('mostra a grade com dias, blocos, config e FAB', (tester) async {
    // Viewport alto: a ListView é preguiçosa e só monta o que está visível —
    // aqui queremos a semana inteira na tela.
    tester.view.physicalSize = const Size(600, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = _GradeRepositoryFake([
      TurmaGrade(
        turma: _turma(
          id: 1,
          codigo: 'FGA0138',
          horario: '246M12',
          nome: 'Métodos de Desenvolvimento de Software',
          local: 'UAC 213',
        ),
      ),
      TurmaGrade(
        turma: _turma(id: 2, codigo: 'FGA0158', horario: '35T34'),
        manual: true,
      ),
    ]);
    final scheduler = _SchedulerFake();

    await tester.pumpWidget(
      _app(auth: _logado(), repo: repo, scheduler: scheduler),
    );
    await tester.pumpAndSettle();

    // Card de configuração.
    expect(find.text('Avisar antes da aula'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
    expect(find.text('30 min'), findsOneWidget);

    // Dias como seções verticais.
    expect(find.text('Seg'), findsOneWidget);
    expect(find.text('Ter'), findsOneWidget);
    expect(find.text('Qua'), findsOneWidget);

    // Blocos com código, horário e local.
    expect(find.text('FGA0138'), findsNWidgets(3)); // Seg/Qua/Sex
    expect(find.text('FGA0158'), findsNWidgets(2)); // Ter/Qui
    expect(find.text('08:00'), findsNWidgets(3));
    expect(find.text('UAC 213'), findsNWidgets(3));

    // Turma manual tem botão de remover; a automática não.
    expect(find.byTooltip('Remover turma'), findsNWidgets(2));

    // FAB de adicionar turma.
    expect(find.widgetWithText(FloatingActionButton, 'Turma'), findsOneWidget);

    // Notificações foram sincronizadas na carga.
    expect(scheduler.sincronizacoes, greaterThan(0));
  });

  testWidgets('visitante sem grade vê o estado vazio explicativo', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        auth: const AuthState.anonymous(),
        repo: _GradeRepositoryFake([]),
        scheduler: _SchedulerFake(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sua grade está vazia'), findsOneWidget);
    expect(find.textContaining('modo visitante'), findsOneWidget);
  });

  testWidgets('turmas em conflito exibem a etiqueta de conflito', (
    tester,
  ) async {
    final repo = _GradeRepositoryFake([
      TurmaGrade(
        turma: _turma(id: 1, codigo: 'FGA0138', horario: '2M12'),
      ),
      TurmaGrade(
        turma: _turma(id: 2, codigo: 'FGA0158', horario: '2M23'),
        manual: true,
      ),
    ]);

    await tester.pumpWidget(
      _app(auth: _logado(), repo: repo, scheduler: _SchedulerFake()),
    );
    await tester.pumpAndSettle();

    expect(find.text('conflito'), findsNWidgets(2));
  });

  testWidgets('remover turma manual atualiza a grade', (tester) async {
    final repo = _GradeRepositoryFake([
      TurmaGrade(
        turma: _turma(id: 2, codigo: 'FGA0158', horario: '35T34'),
        manual: true,
      ),
    ]);

    await tester.pumpWidget(
      _app(auth: _logado(), repo: repo, scheduler: _SchedulerFake()),
    );
    await tester.pumpAndSettle();
    expect(find.text('FGA0158'), findsNWidgets(2));

    await tester.tap(find.byTooltip('Remover turma').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remover'));
    await tester.pumpAndSettle();

    expect(find.text('FGA0158'), findsNothing);
    expect(find.text('Sua grade está vazia'), findsOneWidget);
  });

  testWidgets('ligar o aviso pede init e reagenda as notificações', (
    tester,
  ) async {
    final scheduler = _SchedulerFake();

    await tester.pumpWidget(
      _app(
        auth: _logado(),
        repo: _GradeRepositoryFake([
          TurmaGrade(
            turma: _turma(id: 1, codigo: 'FGA0138', horario: '2M12'),
          ),
        ]),
        scheduler: scheduler,
      ),
    );
    await tester.pumpAndSettle();

    final antes = scheduler.sincronizacoes;
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(scheduler.sincronizacoes, greaterThan(antes));
  });
}
