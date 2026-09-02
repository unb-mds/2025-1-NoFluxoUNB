import 'package:flutter_test/flutter_test.dart';
import 'package:no_fluxo_app/core/models/equivalencia_model.dart';
import 'package:no_fluxo_app/core/models/materia_model.dart';

MateriaModel _cursada(String codigo) => MateriaModel(
  ementa: '',
  idMateria: 0,
  nomeMateria: '',
  codigoMateria: codigo,
  nivel: 0,
  creditos: 0,
);

EquivalenciaModel _eq(String expressao) => EquivalenciaModel(
  idEquivalencia: 0,
  codigoMateriaOrigem: '',
  nomeMateriaOrigem: '',
  codigoMateriaEquivalente: '',
  nomeMateriaEquivalente: '',
  expressao: expressao,
);

void main() {
  group('EquivalenciaModel — parser de expressões E/OU', () {
    test('OU simples sem parênteses', () {
      expect(
        _eq(
          'CIC0001 OU CIC0002',
        ).isMateriaEquivalente([_cursada('CIC0002')]).isEquivalente,
        true,
      );
      expect(
        _eq('CIC0001 OU CIC0002').isMateriaEquivalente([]).isEquivalente,
        false,
      );
    });

    test('E exige os dois lados', () {
      expect(
        _eq(
          'CIC0001 E CIC0002',
        ).isMateriaEquivalente([_cursada('CIC0001')]).isEquivalente,
        false,
      );
      expect(
        _eq('CIC0001 E CIC0002').isMateriaEquivalente([
          _cursada('CIC0001'),
          _cursada('CIC0002'),
        ]).isEquivalente,
        true,
      );
    });

    test(
      'regressão: expressão terminando em ")" acha o operador principal',
      () {
        // Bug herdado do parser legado: o scan começava em length - 2 e pulava
        // o ")" final, deslocando a contagem de parênteses — "A OU ( B )"
        // nunca encontrava o OU e avaliava como falso.
        final eq = _eq('( CCA0105 ) OU ( FUP0289 )');
        expect(
          eq.isMateriaEquivalente([_cursada('FUP0289')]).isEquivalente,
          true,
        );
        expect(
          eq.isMateriaEquivalente([_cursada('CCA0105')]).isEquivalente,
          true,
        );
        expect(
          eq.isMateriaEquivalente([_cursada('MAT0025')]).isEquivalente,
          false,
        );
      },
    );

    test('aninhada: ( A E B ) OU ( C )', () {
      final eq = _eq('( FGA0158 E FGA0161 ) OU ( MAT0025 )');
      expect(
        eq.isMateriaEquivalente([_cursada('MAT0025')]).isEquivalente,
        true,
      );
      expect(
        eq.isMateriaEquivalente([_cursada('FGA0158')]).isEquivalente,
        false,
      );
      expect(
        eq.isMateriaEquivalente([
          _cursada('FGA0158'),
          _cursada('FGA0161'),
        ]).isEquivalente,
        true,
      );
    });
  });
}
