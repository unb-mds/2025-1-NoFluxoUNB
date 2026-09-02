import 'package:flutter_test/flutter_test.dart';
import 'package:no_fluxo_app/core/models/curso_model.dart';

void main() {
  group(
    'PreRequisitoModel.parseExpressaoLogica — normalização como no site',
    () {
      test('{} (DEFAULT da coluna em linhas legadas) vira null', () {
        // Sem isso, a linha legada com só o join de código nunca cai no
        // fallback e o pré-requisito avalia como falso para sempre.
        expect(
          PreRequisitoModel.parseExpressaoLogica(<String, dynamic>{}),
          null,
        );
        expect(PreRequisitoModel.parseExpressaoLogica('{}'), null);
      });

      test('[] vira null', () {
        expect(PreRequisitoModel.parseExpressaoLogica(<dynamic>[]), null);
        expect(PreRequisitoModel.parseExpressaoLogica('[]'), null);
      });

      test('mapa com condicoes ou materias é preservado', () {
        final arvore = {
          'operador': 'OU',
          'condicoes': ['CIC0001', 'CIC0002'],
        };
        expect(PreRequisitoModel.parseExpressaoLogica(arvore), arvore);
        final legado = {
          'operador': 'E',
          'materias': ['CIC0001'],
        };
        expect(PreRequisitoModel.parseExpressaoLogica(legado), legado);
      });

      test(
        'aspas envolventes de valor duplamente codificado são removidas',
        () {
          expect(
            PreRequisitoModel.parseExpressaoLogica('"MAT0026"'),
            'MAT0026',
          );
          expect(
            PreRequisitoModel.parseExpressaoLogica(r'\"MAT0026\"'),
            'MAT0026',
          );
        },
      );

      test('String JSON decodifica e renormaliza recursivamente', () {
        expect(
          PreRequisitoModel.parseExpressaoLogica(
            '{"operador":"OU","condicoes":["CIC0001"]}',
          ),
          {
            'operador': 'OU',
            'condicoes': ['CIC0001'],
          },
        );
      });

      test('mapa sem chaves úteis não conta como expressão (temExpressao)', () {
        final linha = PreRequisitoModel(
          idPreRequisito: 1,
          idMateria: 1,
          idMateriaRequisito: 2,
          codigoMateriaRequisito: 'CIC0001',
          nomeMateriaRequisito: 'X',
          expressaoLogica: PreRequisitoModel.parseExpressaoLogica(
            <String, dynamic>{},
          ),
        );
        expect(linha.temExpressao, false);
      });
    },
  );
}
