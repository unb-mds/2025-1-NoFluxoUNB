import 'package:flutter_test/flutter_test.dart';
import 'package:no_fluxo_app/features/notificacoes/data/notificacoes_repository.dart';

void main() {
  group('ResultadoNotificacoes.fromJson', () {
    test('mapeia o shape completo da RPC listar_notificacoes', () {
      final resultado = ResultadoNotificacoes.fromJson({
        'items': [
          {
            'id_notificacao': 42,
            'created_at': '2026-08-30T12:00:00Z',
            'tipo': 'vaga_aberta',
            'titulo': 'Vaga aberta em FGA0158',
            'mensagem': 'Abriu 1 vaga na turma 01',
            'metadata': {'codigo_materia': 'FGA0158', 'turma': '01'},
            'lida': false,
            'lida_em': null,
          },
          {
            'id_notificacao': 43,
            'created_at': '2026-08-29T08:30:00Z',
            'tipo': 'vaga_aberta',
            'titulo': 'Vaga aberta em MAT0025',
            'mensagem': 'Abriu 2 vagas',
            'metadata': null,
            'lida': true,
            'lida_em': '2026-08-29T09:00:00Z',
          },
        ],
        'total_nao_lidas': 1,
      });

      expect(resultado.totalNaoLidas, 1);
      expect(resultado.items, hasLength(2));

      final primeira = resultado.items.first;
      expect(primeira.idNotificacao, 42);
      expect(primeira.createdAt, DateTime.utc(2026, 8, 30, 12));
      expect(primeira.tipo, 'vaga_aberta');
      expect(primeira.titulo, 'Vaga aberta em FGA0158');
      expect(primeira.mensagem, 'Abriu 1 vaga na turma 01');
      expect(primeira.metadata['codigo_materia'], 'FGA0158');
      expect(primeira.lida, isFalse);
      expect(primeira.lidaEm, isNull);

      final segunda = resultado.items[1];
      expect(segunda.lida, isTrue);
      expect(segunda.lidaEm, DateTime.utc(2026, 8, 29, 9));
      expect(segunda.metadata, isEmpty);
    });

    test('aceita items ausente e total_nao_lidas ausente', () {
      final resultado = ResultadoNotificacoes.fromJson(<String, dynamic>{});
      expect(resultado.items, isEmpty);
      expect(resultado.totalNaoLidas, 0);
    });

    test('aceita retorno nulo ou de tipo inesperado', () {
      expect(ResultadoNotificacoes.fromJson(null).items, isEmpty);
      expect(ResultadoNotificacoes.fromJson('oops').totalNaoLidas, 0);
      expect(ResultadoNotificacoes.fromJson([1, 2]).items, isEmpty);
    });

    test('descarta itens que não são objetos e mantém os válidos', () {
      final resultado = ResultadoNotificacoes.fromJson({
        'items': [
          'lixo',
          123,
          null,
          {'id_notificacao': 7, 'titulo': 'Ok', 'tipo': 't', 'mensagem': 'm'},
        ],
        'total_nao_lidas': 5,
      });
      expect(resultado.items, hasLength(1));
      expect(resultado.items.single.idNotificacao, 7);
      expect(resultado.totalNaoLidas, 5);
    });

    test(
      'parsing defensivo de tipos frouxos (int como string, lida como 1)',
      () {
        final resultado = ResultadoNotificacoes.fromJson({
          'items': [
            {
              'id_notificacao': '99',
              'created_at': 'data-invalida',
              'tipo': null,
              'titulo': null,
              'mensagem': null,
              'metadata': {'codigo_materia': 'FGA0030'},
              'lida': 1,
            },
          ],
          'total_nao_lidas': '3',
        });

        final item = resultado.items.single;
        expect(item.idNotificacao, 99);
        expect(item.createdAt, isNull);
        expect(item.tipo, '');
        expect(item.titulo, '');
        expect(item.mensagem, '');
        expect(item.lida, isTrue);
        expect(resultado.totalNaoLidas, 3);
      },
    );
  });
}
