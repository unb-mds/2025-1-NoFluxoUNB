import 'package:flutter_test/flutter_test.dart';
import 'package:no_fluxo_app/core/models/user_model.dart';
import 'package:no_fluxo_app/features/perfil/domain/progresso_calculator.dart';

/// Fixture de fluxograma: 3 semestres com um mix de status do SIGAA.
DadosFluxogramaUser _fluxogramaFixture() {
  return DadosFluxogramaUser(
    nomeCurso: 'Engenharia de Software',
    matrizCurricular: '6360/2 - 2017.1',
    semestreAtual: 5,
    ira: 4.1234,
    iraTexto: '4,1234',
    dadosFluxograma: [
      [
        DadosMateria(codigoMateria: 'MAT0025', status: 'APR', mencao: 'MS'),
        DadosMateria(codigoMateria: 'FGA0158', status: 'CUMP'),
      ],
      [
        DadosMateria(codigoMateria: 'FGA0161', status: 'DISP'),
        DadosMateria(codigoMateria: 'FGA0312', status: 'MATR'),
      ],
      [
        DadosMateria(codigoMateria: 'FGA0108', status: 'REP', mencao: 'MI'),
        DadosMateria(codigoMateria: 'FGA0242', status: '-'),
      ],
    ],
  );
}

void main() {
  group('ProgressoCalculator.percentual', () {
    test('calcula realizado/exigido * 100', () {
      expect(ProgressoCalculator.percentual(1230, 2400), closeTo(51.25, 1e-9));
    });

    test('clampa em 100 quando realizado excede o exigido', () {
      expect(ProgressoCalculator.percentual(2600, 2400), 100);
    });

    test('clampa em 0 para realizado negativo (dado corrompido)', () {
      expect(ProgressoCalculator.percentual(-10, 2400), 0);
    });

    test('exigido = 0 não divide por zero e retorna 0', () {
      expect(ProgressoCalculator.percentual(500, 0), 0);
    });

    test('exigido null (matriz sem o dado) retorna 0', () {
      expect(ProgressoCalculator.percentual(500, null), 0);
    });
  });

  group('ProgressoCalculator.horasFaltantes', () {
    test('exigido - realizado', () {
      expect(ProgressoCalculator.horasFaltantes(1230, 2400), 1170);
    });

    test('nunca negativo quando já passou do exigido', () {
      expect(ProgressoCalculator.horasFaltantes(2600, 2400), 0);
    });

    test('exigido null ou zero retorna 0', () {
      expect(ProgressoCalculator.horasFaltantes(100, null), 0);
      expect(ProgressoCalculator.horasFaltantes(100, 0), 0);
    });
  });

  group('ProgressoCalculator.contarMaterias', () {
    test('conta concluídas (APR/CUMP/DISP), em curso (MATR) e pendentes', () {
      final contagem = ProgressoCalculator.contarMaterias(_fluxogramaFixture());
      expect(contagem.concluidas, 3);
      expect(contagem.emCurso, 1);
      expect(contagem.pendentes, 2); // REP e "-"
      expect(contagem.total, 6);
    });

    test('fluxograma null retorna tudo zerado', () {
      final contagem = ProgressoCalculator.contarMaterias(null);
      expect(contagem.concluidas, 0);
      expect(contagem.emCurso, 0);
      expect(contagem.pendentes, 0);
    });
  });

  group('ProgressoCalculator.calcular', () {
    const integralizada = CargaHorariaIntegralizada(
      obrigatoria: 1230,
      optativa: 300,
      complementar: 60,
      total: 1590,
    );
    const exigencias = ExigenciasMatriz(
      curriculoCompleto: '6360/2 - 2017.1',
      chObrigatoriaExigida: 2400,
      chOptativaExigida: 900,
      chComplementarExigida: 120,
      chTotalExigida: 3420,
    );

    test('monta percentuais e faltantes por natureza', () {
      final p = ProgressoCalculator.calcular(
        integralizada: integralizada,
        exigencias: exigencias,
        dados: _fluxogramaFixture(),
      );
      expect(p.obrigatoria.percentual, closeTo(51.25, 1e-9));
      expect(p.obrigatoria.faltam, 1170);
      expect(p.optativa.percentual, closeTo(100 * 300 / 900, 1e-9));
      expect(p.total.faltam, 3420 - 1590);
      expect(p.temComplementar, isTrue);
      expect(p.contagem.concluidas, 3);
    });

    test(
      'sem exigências da matriz: percentuais 0 e sem barra complementar',
      () {
        final p = ProgressoCalculator.calcular(integralizada: integralizada);
        expect(p.total.percentual, 0);
        expect(p.total.realizado, 1590);
        expect(p.temComplementar, isFalse);
        expect(p.obrigatoria.temExigencia, isFalse);
      },
    );

    test('sem carga integralizada usa horas_integralizadas só no total', () {
      final p = ProgressoCalculator.calcular(
        exigencias: exigencias,
        horasIntegralizadasFallback: 1500,
      );
      expect(p.total.realizado, 1500);
      expect(p.obrigatoria.realizado, 0);
    });
  });

  group('CargaHorariaIntegralizada.fromDynamic', () {
    test('aceita Map (coluna jsonb)', () {
      final c = CargaHorariaIntegralizada.fromDynamic({
        'total': 1590,
        'obrigatoria': 1230,
        'optativa': 300,
        'complementar': 60,
      });
      expect(c, isNotNull);
      expect(c!.total, 1590);
      expect(c.obrigatoria, 1230);
    });

    test('aceita String JSON', () {
      final c = CargaHorariaIntegralizada.fromDynamic(
        '{"total": 100, "obrigatoria": 80, "optativa": 20}',
      );
      expect(c!.total, 100);
      expect(c.complementar, 0); // campo ausente → 0
    });

    test('null ou lixo retorna null', () {
      expect(CargaHorariaIntegralizada.fromDynamic(null), isNull);
      expect(CargaHorariaIntegralizada.fromDynamic('não é json'), isNull);
    });
  });

  group('ExigenciasMatriz.fromJson', () {
    test('parseia campos e tolera ausentes', () {
      final e = ExigenciasMatriz.fromJson({
        'curriculo_completo': '6360/2 - 2017.1',
        'ch_obrigatoria_exigida': 2400,
        'ch_total_exigida': '3420', // int como String não estoura
      });
      expect(e.chObrigatoriaExigida, 2400);
      expect(e.chTotalExigida, 3420);
      expect(e.chOptativaExigida, isNull);
      expect(e.chComplementarExigida, isNull);
    });
  });

  group('formatarHorasPtBr', () {
    test('separa milhares com ponto', () {
      expect(formatarHorasPtBr(0), '0');
      expect(formatarHorasPtBr(999), '999');
      expect(formatarHorasPtBr(1230), '1.230');
      expect(formatarHorasPtBr(1234567), '1.234.567');
    });
  });

  group('iniciaisDoNome', () {
    test('primeiro e último nome', () {
      expect(iniciaisDoNome('Ana Beatriz Silva'), 'AS');
      expect(iniciaisDoNome('ana'), 'A');
      expect(iniciaisDoNome('  '), '?');
    });
  });
}
