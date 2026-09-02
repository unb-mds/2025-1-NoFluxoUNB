import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_fluxo_app/core/services/auth_service.dart';
import 'package:no_fluxo_app/features/notificacoes/providers/notificacoes_provider.dart';

import 'fakes.dart';

/// Dá tempo para os microtasks/futures do notifier resolverem.
Future<void> assentar() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

ProviderContainer containerCom(
  FakeNotificacoesRepository repo, {
  bool logado = true,
}) {
  final container = ProviderContainer(
    overrides: [
      notificacoesRepositoryProvider.overrideWithValue(repo),
      authProvider.overrideWith(
        () => logado ? FakeAuthLogado() : FakeAuthVisitante(),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('unreadCountProvider', () {
    test('visitante: contagem fica em 0 e não consulta o banco', () async {
      final repo = FakeNotificacoesRepository(totalNaoLidas: 7);
      final container = containerCom(repo, logado: false);

      expect(container.read(unreadCountProvider), 0);
      await assentar();
      expect(container.read(unreadCountProvider), 0);
      expect(repo.chamadasListar, 0);
      expect(repo.assinaturasAtivas, 0);
    });

    test('logado: carrega a contagem e assina o Realtime', () async {
      final repo = FakeNotificacoesRepository(totalNaoLidas: 3);
      final container = containerCom(repo);

      // Mantém o provider vivo durante o teste.
      final sub = container.listen(unreadCountProvider, (_, _) {});
      addTearDown(sub.close);

      await assentar();
      expect(container.read(unreadCountProvider), 3);
      expect(repo.assinaturasAtivas, 1);
    });

    test('INSERT via Realtime refaz a contagem', () async {
      final repo = FakeNotificacoesRepository(totalNaoLidas: 1);
      final container = containerCom(repo);
      final sub = container.listen(unreadCountProvider, (_, _) {});
      addTearDown(sub.close);
      await assentar();
      expect(container.read(unreadCountProvider), 1);

      // Simula uma nova notificação chegando pelo canal.
      repo.totalNaoLidas = 2;
      repo.onNovaNotificacao!();
      await assentar();

      expect(container.read(unreadCountProvider), 2);
    });

    test('falha do Realtime cai para polling periódico', () async {
      // Encurta o intervalo (60s em produção) para o teste não esperar.
      final intervaloOriginal = UnreadCountNotifier.intervaloPolling;
      UnreadCountNotifier.intervaloPolling = const Duration(milliseconds: 20);
      addTearDown(() {
        UnreadCountNotifier.intervaloPolling = intervaloOriginal;
      });

      final repo = FakeNotificacoesRepository(totalNaoLidas: 1);
      final container = containerCom(repo);
      final sub = container.listen(unreadCountProvider, (_, _) {});
      addTearDown(sub.close);

      await assentar();
      expect(container.read(unreadCountProvider), 1);

      // Realtime indisponível (tabela fora da publicação) → fallback.
      repo.onFalhaRealtime!();
      repo.totalNaoLidas = 4;

      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(container.read(unreadCountProvider), 4);
    });

    test('erro na RPC é silencioso e mantém a última contagem', () async {
      final repo = FakeNotificacoesRepository(totalNaoLidas: 2);
      final container = containerCom(repo);
      final sub = container.listen(unreadCountProvider, (_, _) {});
      addTearDown(sub.close);
      await assentar();
      expect(container.read(unreadCountProvider), 2);

      repo.erroAoListar = Exception('rede caiu');
      repo.onNovaNotificacao!();
      await assentar();

      expect(container.read(unreadCountProvider), 2);
    });

    test('definirContagem sincroniza o badge sem ir ao banco', () async {
      final repo = FakeNotificacoesRepository(totalNaoLidas: 5);
      final container = containerCom(repo);
      final sub = container.listen(unreadCountProvider, (_, _) {});
      addTearDown(sub.close);
      await assentar();

      final chamadasAntes = repo.chamadasListar;
      container.read(unreadCountProvider.notifier).definirContagem(0);

      expect(container.read(unreadCountProvider), 0);
      expect(repo.chamadasListar, chamadasAntes);
    });
  });

  group('notificacoesProvider (integração com o badge)', () {
    test('marcarTodasComoLidas chama RPC com null e zera o badge', () async {
      final repo = FakeNotificacoesRepository(
        notificacoes: [notificacaoDeTeste(id: 1), notificacaoDeTeste(id: 2)],
        totalNaoLidas: 2,
      );
      final container = containerCom(repo);
      final subLista = container.listen(notificacoesProvider, (_, _) {});
      final subBadge = container.listen(unreadCountProvider, (_, _) {});
      addTearDown(subLista.close);
      addTearDown(subBadge.close);

      await container.read(notificacoesProvider.future);
      // O badge rebuilda quando o auth resolve — espera a recarga assentar.
      await assentar();
      expect(container.read(unreadCountProvider), 2);

      await container
          .read(notificacoesProvider.notifier)
          .marcarTodasComoLidas();

      expect(repo.chamadasMarcarLida, [null]);
      expect(container.read(unreadCountProvider), 0);
      final estado = container.read(notificacoesProvider).requireValue;
      expect(estado.totalNaoLidas, 0);
      expect(estado.notificacoes.every((n) => n.lida), isTrue);
    });

    test('marcarComoLida marca uma e decrementa o badge', () async {
      final alvo = notificacaoDeTeste(id: 10);
      final repo = FakeNotificacoesRepository(
        notificacoes: [alvo, notificacaoDeTeste(id: 11)],
        totalNaoLidas: 2,
      );
      final container = containerCom(repo);
      final sub = container.listen(notificacoesProvider, (_, _) {});
      addTearDown(sub.close);

      await container.read(notificacoesProvider.future);
      // Deixa a carga inicial do badge terminar antes de marcar como lida.
      await assentar();
      await container.read(notificacoesProvider.notifier).marcarComoLida(alvo);

      expect(repo.chamadasMarcarLida, [10]);
      expect(container.read(unreadCountProvider), 1);
      final estado = container.read(notificacoesProvider).requireValue;
      expect(
        estado.notificacoes.firstWhere((n) => n.idNotificacao == 10).lida,
        isTrue,
      );
    });

    test('alternarSomenteNaoLidas repassa o filtro para a RPC', () async {
      final repo = FakeNotificacoesRepository(
        notificacoes: [
          notificacaoDeTeste(id: 1, lida: true),
          notificacaoDeTeste(id: 2),
        ],
        totalNaoLidas: 1,
      );
      final container = containerCom(repo);
      final sub = container.listen(notificacoesProvider, (_, _) {});
      addTearDown(sub.close);

      await container.read(notificacoesProvider.future);
      await container
          .read(notificacoesProvider.notifier)
          .alternarSomenteNaoLidas(true);

      expect(repo.filtrosListagem, [false, true]);
      final estado = container.read(notificacoesProvider).requireValue;
      expect(estado.somenteNaoLidas, isTrue);
      expect(estado.notificacoes.map((n) => n.idNotificacao), [2]);
    });
  });
}
