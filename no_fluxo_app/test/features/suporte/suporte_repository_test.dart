import 'package:flutter_test/flutter_test.dart';
import 'package:no_fluxo_app/features/suporte/data/suporte_repository.dart';
import 'package:no_fluxo_app/features/suporte/data/ticket_model.dart';

void main() {
  group('montarInsertTicket (shape do INSERT, espelho do site)', () {
    test('monta o payload exato esperado pela tabela tickets', () {
      final payload = SupabaseSuporteRepository.montarInsertTicket(
        authId: 'uuid-do-auth',
        title: '  App trava no fluxograma  ',
        description: '  Ao abrir a aba ele fecha.  ',
        categoria: TicketCategoria.bug,
        metadata: const {'platform': 'android'},
      );

      expect(payload, {
        'created_by': 'uuid-do-auth',
        'title': 'App trava no fluxograma', // trim, igual ao site
        'description': 'Ao abrir a aba ele fecha.',
        'category': 'bug',
        'status': 'aberto',
        'metadata': {'platform': 'android'},
        'attachments': <dynamic>[], // v1 do app: sem anexos
      });
    });

    test('categoria vai com o valor do banco (sugestao/duvida sem acento)', () {
      for (final (categoria, valor) in [
        (TicketCategoria.bug, 'bug'),
        (TicketCategoria.sugestao, 'sugestao'),
        (TicketCategoria.duvida, 'duvida'),
      ]) {
        final payload = SupabaseSuporteRepository.montarInsertTicket(
          authId: 'x',
          title: 't',
          description: 'd',
          categoria: categoria,
          metadata: const {},
        );
        expect(payload['category'], valor);
      }
    });
  });

  group('coletarMetadata', () {
    test('tem platform, app_version fixa e os_version', () {
      final meta = SupabaseSuporteRepository.coletarMetadata();
      expect(meta['platform'], anyOf('android', 'ios'));
      expect(meta['app_version'], kSuporteAppVersion);
      expect(meta['os_version'], isA<String>());
    });
  });

  group('TicketModel parsing defensivo', () {
    test('parseia uma linha completa do banco', () {
      final t = TicketModel.fromJson(const {
        'id': 7,
        'created_by': 'uuid-1',
        'title': 'Sugestão de dark mode',
        'description': 'Seria ótimo',
        'category': 'sugestao',
        'status': 'em_andamento',
        'metadata': {'platform': 'ios'},
        'created_at': '2026-08-30T12:00:00Z',
      });
      expect(t.id, 7);
      expect(t.createdBy, 'uuid-1');
      expect(t.categoria, TicketCategoria.sugestao);
      expect(t.status, 'em_andamento');
      expect(t.statusLabel, 'Em andamento');
      expect(t.metadata['platform'], 'ios');
      expect(t.createdAt, DateTime.utc(2026, 8, 30, 12));
    });

    test('não estoura com mapa vazio ou tipos errados', () {
      final vazio = TicketModel.fromJson(const {});
      expect(vazio.id, 0);
      expect(vazio.status, 'aberto');
      expect(vazio.createdAt, isNull);
      expect(vazio.categoria, isNull);

      final torto = TicketModel.fromJson(const {
        'id': 'not-a-number',
        'title': 123,
        'status': null,
        'metadata': 'not-a-map',
        'created_at': 'not-a-date',
      });
      expect(torto.title, '123');
      expect(torto.status, 'aberto');
      expect(torto.metadata, isEmpty);
      expect(torto.createdAt, isNull);
    });

    test('statusLabel cobre os status conhecidos e degrada nos demais', () {
      expect(ticket('aberto').statusLabel, 'Aberto');
      expect(ticket('aguardando_info').statusLabel, 'Aguardando info');
      expect(ticket('resolvido').statusLabel, 'Resolvido');
      expect(ticket('fechado').statusLabel, 'Fechado');
      expect(ticket('outro_status').statusLabel, 'outro_status');
    });
  });
}

TicketModel ticket(String status) => TicketModel(status: status);
