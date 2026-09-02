import 'package:flutter_test/flutter_test.dart';
import 'package:no_fluxo_app/core/services/push_service.dart';

void main() {
  group('rotaDeDeepLinkPush', () {
    test('converte codigo_materia em rota de turmas', () {
      final rota = rotaDeDeepLinkPush({
        'codigo_materia': 'FGA0158',
        'turma': '01',
        'ano_periodo': '2026.1',
        'vagas_sobrando': '3',
      });
      expect(rota, '/turmas?codigo=FGA0158');
    });

    test('faz URL-encode de códigos com caracteres especiais', () {
      // Espaço vira "+" em query component (decodificado de volta pelo Uri).
      final rota = rotaDeDeepLinkPush({'codigo_materia': 'FGA 01/58'});
      expect(rota, '/turmas?codigo=FGA+01%2F58');
      expect(Uri.parse(rota!).queryParameters['codigo'], 'FGA 01/58');
    });

    test('ignora espaços em volta do código', () {
      final rota = rotaDeDeepLinkPush({'codigo_materia': '  FGA0158  '});
      expect(rota, '/turmas?codigo=FGA0158');
    });

    test('usa o deep_link quando não há codigo_materia', () {
      final rota = rotaDeDeepLinkPush({
        'deep_link': 'nofluxo://turmas?codigo=MAT0025',
      });
      expect(rota, '/turmas?codigo=MAT0025');
    });

    test('prefere codigo_materia ao deep_link quando ambos existem', () {
      final rota = rotaDeDeepLinkPush({
        'codigo_materia': 'FGA0158',
        'deep_link': 'nofluxo://turmas?codigo=MAT0025',
      });
      expect(rota, '/turmas?codigo=FGA0158');
    });

    test('codigo_materia vazio cai no deep_link', () {
      final rota = rotaDeDeepLinkPush({
        'codigo_materia': '',
        'deep_link': 'nofluxo://turmas?codigo=MAT0025',
      });
      expect(rota, '/turmas?codigo=MAT0025');
    });

    test('rejeita deep_link de scheme desconhecido', () {
      final rota = rotaDeDeepLinkPush({
        'deep_link': 'https://exemplo.com/turmas?codigo=MAT0025',
      });
      expect(rota, isNull);
    });

    test('rejeita deep_link nofluxo para host desconhecido', () {
      final rota = rotaDeDeepLinkPush({
        'deep_link': 'nofluxo://perfil?codigo=MAT0025',
      });
      expect(rota, isNull);
    });

    test('deep_link nofluxo://turmas sem codigo abre a aba de turmas', () {
      final rota = rotaDeDeepLinkPush({'deep_link': 'nofluxo://turmas'});
      expect(rota, '/turmas');
    });

    test('retorna null para data vazia', () {
      expect(rotaDeDeepLinkPush(const {}), isNull);
    });

    test('retorna null para valores não-string sem código', () {
      expect(rotaDeDeepLinkPush({'deep_link': 42}), isNull);
    });

    test('aceita codigo_materia numérico convertendo para string', () {
      // FCM entrega tudo como string, mas a função é defensiva.
      final rota = rotaDeDeepLinkPush({'codigo_materia': 123});
      expect(rota, '/turmas?codigo=123');
    });
  });

  group('decidirAcaoInitPush', () {
    test('sem Firebase → ignorar', () {
      expect(
        decidirAcaoInitPush(firebaseDisponivel: false, jaInicializado: false),
        AcaoInitPush.ignorar,
      );
      expect(
        decidirAcaoInitPush(firebaseDisponivel: false, jaInicializado: true),
        AcaoInitPush.ignorar,
      );
    });

    test('primeira chamada → configura listeners E registra o token', () {
      expect(
        decidirAcaoInitPush(firebaseDisponivel: true, jaInicializado: false),
        AcaoInitPush.configurarERegistrar,
      );
    });

    test('chamadas seguintes SEMPRE re-registram o token (logout→login de '
        'outra conta no mesmo aparelho)', () {
      // Regressão: antes, init() era no-op quando já inicializado e o
      // token nunca era re-registrado após relogin.
      expect(
        decidirAcaoInitPush(firebaseDisponivel: true, jaInicializado: true),
        AcaoInitPush.apenasRegistrar,
      );
    });
  });
}
