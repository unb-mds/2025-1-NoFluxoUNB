import 'package:flutter_test/flutter_test.dart';
import 'package:no_fluxo_app/features/notificacoes/utils/tempo_relativo.dart';

void main() {
  final agora = DateTime(2026, 8, 31, 12, 0, 0);

  String fmt(Duration atras) =>
      formatarTempoRelativo(agora.subtract(atras), agora: agora);

  group('formatarTempoRelativo', () {
    test('data nula vira string vazia', () {
      expect(formatarTempoRelativo(null, agora: agora), '');
    });

    test('menos de 1 minuto (e datas futuras) vira "agora"', () {
      expect(fmt(Duration.zero), 'agora');
      expect(fmt(const Duration(seconds: 59)), 'agora');
      expect(fmt(const Duration(seconds: -30)), 'agora');
    });

    test('minutos: "há 5 min"', () {
      expect(fmt(const Duration(minutes: 1)), 'há 1 min');
      expect(fmt(const Duration(minutes: 5)), 'há 5 min');
      expect(fmt(const Duration(minutes: 59)), 'há 59 min');
    });

    test('horas: "há 3 h"', () {
      expect(fmt(const Duration(hours: 1)), 'há 1 h');
      expect(fmt(const Duration(hours: 3, minutes: 20)), 'há 3 h');
      expect(fmt(const Duration(hours: 23, minutes: 59)), 'há 23 h');
    });

    test('dias: singular e plural', () {
      expect(fmt(const Duration(days: 1)), 'há 1 dia');
      expect(fmt(const Duration(days: 2)), 'há 2 dias');
      expect(fmt(const Duration(days: 6, hours: 23)), 'há 6 dias');
    });

    test('7 dias ou mais vira data absoluta dd/MM/yyyy', () {
      expect(fmt(const Duration(days: 7)), '24/08/2026');
      expect(fmt(const Duration(days: 40)), '22/07/2026');
    });

    test('funciona com created_at em UTC comparado a agora local', () {
      // difference() compara instantes, então o fuso não distorce a conta.
      final criadaUtc = agora.toUtc().subtract(const Duration(minutes: 10));
      expect(formatarTempoRelativo(criadaUtc, agora: agora), 'há 10 min');
    });
  });
}
