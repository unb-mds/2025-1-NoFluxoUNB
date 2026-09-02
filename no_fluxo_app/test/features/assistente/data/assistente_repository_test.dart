import 'package:flutter_test/flutter_test.dart';
import 'package:no_fluxo_app/core/services/api_client.dart';
import 'package:no_fluxo_app/features/assistente/data/assistente_repository.dart';

/// ApiClient fake: registra a chamada e devolve resposta/erro programados.
///
/// `implements` em vez de tocar no HTTP real — o ApiClient de verdade lê o
/// token do Supabase (não inicializado em teste).
class FakeApiClient implements ApiClient {
  Object? resposta;
  Object? erro;
  Duration atraso = Duration.zero;

  final List<({String path, Object? body, bool autenticado})> chamadas = [];

  @override
  Future<dynamic> postJson(
    String path,
    Object? body, {
    bool autenticado = false,
  }) async {
    chamadas.add((path: path, body: body, autenticado: autenticado));
    if (atraso > Duration.zero) await Future<void>.delayed(atraso);
    if (erro != null) throw erro!;
    return resposta;
  }

  @override
  Future<dynamic> getJson(
    String path, {
    Map<String, String>? query,
    bool autenticado = false,
  }) async => throw UnimplementedError();

  @override
  void dispose() {}
}

void main() {
  test(
    'envia POST /chat/send autenticado com message e devolve o reply',
    () async {
      final api = FakeApiClient()..resposta = {'reply': 'Oi, sou o Darcy!'};
      final repo = AssistenteRepository(api);

      final reply = await repo.enviarMensagem('O que falta para me formar?');

      expect(reply, 'Oi, sou o Darcy!');
      final chamada = api.chamadas.single;
      expect(chamada.path, '/chat/send');
      expect(chamada.autenticado, isTrue);
      expect(chamada.body, {'message': 'O que falta para me formar?'});
    },
  );

  test('inclui curriculoCompleto no body quando informado', () async {
    final api = FakeApiClient()..resposta = {'reply': 'ok'};
    final repo = AssistenteRepository(api);

    await repo.enviarMensagem('oi', curriculoCompleto: '8899/2');

    expect(api.chamadas.single.body, {
      'message': 'oi',
      'curriculoCompleto': '8899/2',
    });
  });

  test('curriculoCompleto vazio/nulo fica fora do body', () async {
    final api = FakeApiClient()..resposta = {'reply': 'ok'};
    final repo = AssistenteRepository(api);

    await repo.enviarMensagem('oi', curriculoCompleto: '   ');

    expect(api.chamadas.single.body, {'message': 'oi'});
  });

  test('401 vira mensagem de sessão expirada', () async {
    final api = FakeApiClient()
      ..erro = const ApiException(401, '{"error":"Token inválido."}');
    final repo = AssistenteRepository(api);

    await expectLater(
      repo.enviarMensagem('oi'),
      throwsA(
        isA<AssistenteException>().having(
          (e) => e.mensagem,
          'mensagem',
          contains('sessão expirou'),
        ),
      ),
    );
  });

  test('503 vira mensagem de serviço indisponível', () async {
    final api = FakeApiClient()
      ..erro = const ApiException(
        503,
        '{"error":"Serviço de chat indisponível."}',
      );
    final repo = AssistenteRepository(api);

    await expectLater(
      repo.enviarMensagem('oi'),
      throwsA(
        isA<AssistenteException>().having(
          (e) => e.mensagem,
          'mensagem',
          contains('indisponível'),
        ),
      ),
    );
  });

  test('400 usa o campo error do corpo JSON', () async {
    final api = FakeApiClient()
      ..erro = const ApiException(
        400,
        '{"error":"O campo \'message\' é obrigatório."}',
      );
    final repo = AssistenteRepository(api);

    await expectLater(
      repo.enviarMensagem('oi'),
      throwsA(
        isA<AssistenteException>().having(
          (e) => e.mensagem,
          'mensagem',
          contains('obrigatório'),
        ),
      ),
    );
  });

  test('resposta sem reply vira AssistenteException', () async {
    final api = FakeApiClient()..resposta = {'foo': 'bar'};
    final repo = AssistenteRepository(api);

    await expectLater(
      repo.enviarMensagem('oi'),
      throwsA(isA<AssistenteException>()),
    );
  });

  test('estouro do timeout vira mensagem amigável de demora', () async {
    final api = FakeApiClient()
      ..resposta = {'reply': 'tarde demais'}
      ..atraso = const Duration(milliseconds: 200);
    final repo = AssistenteRepository(
      api,
      timeout: const Duration(milliseconds: 20),
    );

    await expectLater(
      repo.enviarMensagem('oi'),
      throwsA(
        isA<AssistenteException>().having(
          (e) => e.mensagem,
          'mensagem',
          contains('demorou'),
        ),
      ),
    );
  });

  test('falha de rede genérica vira mensagem de conexão', () async {
    final api = FakeApiClient()..erro = Exception('Connection refused');
    final repo = AssistenteRepository(api);

    await expectLater(
      repo.enviarMensagem('oi'),
      throwsA(
        isA<AssistenteException>().having(
          (e) => e.mensagem,
          'mensagem',
          contains('conectar'),
        ),
      ),
    );
  });
}
