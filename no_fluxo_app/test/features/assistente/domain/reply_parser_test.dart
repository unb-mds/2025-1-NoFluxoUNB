import 'package:flutter_test/flutter_test.dart';
import 'package:no_fluxo_app/features/assistente/domain/reply_parser.dart';

void main() {
  group('parseReply — texto puro', () {
    test('texto simples vira uma bolha com um segmento de texto', () {
      final blocos = parseReply('Olá! Como posso ajudar?');

      expect(blocos, hasLength(1));
      final bolha = blocos.single as BlocoBolha;
      expect(bolha.segmentos, hasLength(1));
      final segmento = bolha.segmentos.single as SegmentoTexto;
      expect(segmento.valor, 'Olá! Como posso ajudar?');
    });

    test('string vazia não gera bloco nenhum', () {
      expect(parseReply(''), isEmpty);
      expect(parseReply('   \n  '), isEmpty);
    });

    test('excesso de linhas em branco é colapsado para uma só', () {
      final blocos = parseReply('linha 1\n\n\n\nlinha 2');
      final bolha = blocos.single as BlocoBolha;
      final texto = (bolha.segmentos.single as SegmentoTexto).valor;
      expect(texto, 'linha 1\n\nlinha 2');
    });

    test('itens de lista viram bullets e listas numeradas ganham espaço', () {
      final blocos = parseReply(
        '- primeiro\n* segundo\n1. terceiro\n2) quarto',
      );
      final texto =
          ((blocos.single as BlocoBolha).segmentos.single as SegmentoTexto)
              .valor;
      expect(texto, '•  primeiro\n•  segundo\n1.  terceiro\n2.  quarto');
    });
  });

  group('parseReply — negrito', () {
    test('**negrito** vira segmento próprio dentro da bolha', () {
      final blocos = parseReply('Você precisa de **120 créditos** ainda.');

      final bolha = blocos.single as BlocoBolha;
      expect(bolha.segmentos, hasLength(3));
      expect((bolha.segmentos[0] as SegmentoTexto).valor, 'Você precisa de ');
      expect((bolha.segmentos[1] as SegmentoNegrito).valor, '120 créditos');
      expect((bolha.segmentos[2] as SegmentoTexto).valor, ' ainda.');
    });

    test('negrito sem fechamento degrada para texto cru', () {
      final blocos = parseReply('isso **não fecha');
      final bolha = blocos.single as BlocoBolha;
      expect(bolha.segmentos, hasLength(1));
      expect(
        (bolha.segmentos.single as SegmentoTexto).valor,
        'isso **não fecha',
      );
    });
  });

  group('parseReply — badge de código de matéria', () {
    test('código ABC1234 vira badge inline', () {
      final blocos = parseReply('Falta cursar CIC0007 este semestre.');

      final bolha = blocos.single as BlocoBolha;
      expect(bolha.segmentos, hasLength(3));
      expect((bolha.segmentos[1] as SegmentoBadge).codigo, 'CIC0007');
    });

    test(
      'código de 3 letras (ex. FGA na variante MAT0025) também vira badge',
      () {
        final blocos = parseReply('Veja MAT0025.');
        final bolha = blocos.single as BlocoBolha;
        expect((bolha.segmentos[1] as SegmentoBadge).codigo, 'MAT0025');
      },
    );

    test('badge e negrito convivem na mesma bolha', () {
      final blocos = parseReply('**Importante**: CIC0004 tem pré-requisito.');

      final bolha = blocos.single as BlocoBolha;
      expect((bolha.segmentos[0] as SegmentoNegrito).valor, 'Importante');
      expect((bolha.segmentos[1] as SegmentoTexto).valor, ': ');
      expect((bolha.segmentos[2] as SegmentoBadge).codigo, 'CIC0004');
    });

    test('palavra minúscula com números não vira badge', () {
      final blocos = parseReply('turma cic0007 não conta');
      final bolha = blocos.single as BlocoBolha;
      expect(bolha.segmentos, hasLength(1));
      expect(bolha.segmentos.single, isA<SegmentoTexto>());
    });
  });

  group('parseReply — [TURMA|...]', () {
    test('marcador completo (com período) vira card de turma', () {
      final blocos = parseReply(
        'Achei esta:\n'
        '[TURMA|01|Edson Alves|35T23|PJC BT-104|10|2025.2]\n'
        'Boa opção!',
      );

      expect(blocos, hasLength(3));
      final turma = (blocos[1] as BlocoTurma).turma;
      expect(turma.turma, '01');
      expect(turma.professor, 'Edson Alves');
      expect(turma.horario, '35T23');
      expect(turma.local, 'PJC BT-104');
      expect(turma.vagas, '10');
      expect(turma.periodo, '2025.2');

      final antes = (blocos[0] as BlocoBolha).segmentos.single as SegmentoTexto;
      expect(antes.valor, contains('Achei esta:'));
      final depois =
          (blocos[2] as BlocoBolha).segmentos.single as SegmentoTexto;
      expect(depois.valor, contains('Boa opção!'));
    });

    test('marcador sem período deixa periodo nulo', () {
      final blocos = parseReply('[TURMA|02|Maria|24M12|ICC Sul|5]');
      final turma = (blocos.single as BlocoTurma).turma;
      expect(turma.periodo, isNull);
      expect(turma.vagas, '5');
    });

    test('campos são aparados (trim)', () {
      final blocos = parseReply('[TURMA| 01 | João | 24M12 | FCTE | 3 ]');
      final turma = (blocos.single as BlocoTurma).turma;
      expect(turma.turma, '01');
      expect(turma.professor, 'João');
      expect(turma.vagas, '3');
    });

    test('marcador malformado (poucos campos) degrada para texto cru', () {
      final blocos = parseReply('[TURMA|01|Edson]');
      final bolha = blocos.single as BlocoBolha;
      expect(
        (bolha.segmentos.single as SegmentoTexto).valor,
        '[TURMA|01|Edson]',
      );
    });
  });

  group('parseReply — [BOTAO|...]', () {
    test('botão com label e mensagem própria', () {
      final blocos = parseReply('[BOTAO|Ver optativas|Me recomenda optativas]');

      final grupo = blocos.single as BlocoBotoes;
      expect(grupo.botoes, hasLength(1));
      expect(grupo.botoes.single.label, 'Ver optativas');
      expect(grupo.botoes.single.mensagem, 'Me recomenda optativas');
    });

    test('botão sem mensagem usa o label como mensagem', () {
      final blocos = parseReply('[BOTAO|Quero me formar logo]');
      final botao = (blocos.single as BlocoBotoes).botoes.single;
      expect(botao.mensagem, 'Quero me formar logo');
    });

    test('label camelCase ganha espaços (como no site)', () {
      final blocos = parseReply('[BOTAO|VerOptativas|msg]');
      final botao = (blocos.single as BlocoBotoes).botoes.single;
      expect(botao.label, 'Ver Optativas');
      expect(botao.mensagem, 'msg');
    });

    test('botões consecutivos são agrupados num único bloco', () {
      final blocos = parseReply(
        'Escolha:\n[BOTAO|Sim|sim][BOTAO|Não|não]\nE aí?',
      );

      expect(blocos, hasLength(3));
      final grupo = blocos[1] as BlocoBotoes;
      expect(grupo.botoes.map((b) => b.label), ['Sim', 'Não']);
    });

    test('botão malformado (vazio) degrada para texto cru', () {
      final blocos = parseReply('[BOTAO|]');
      final bolha = blocos.single as BlocoBolha;
      expect((bolha.segmentos.single as SegmentoTexto).valor, '[BOTAO|]');
    });
  });

  group('parseReply — [MONTAR_GRADE|...]', () {
    test('é ignorado no v1 (não vira bloco), sem engolir o texto ao redor', () {
      final blocos = parseReply(
        'Sua grade:\n[MONTAR_GRADE|CIC0007,MAT0025|M,T]\nDepois me conta.',
      );

      expect(blocos, hasLength(2));
      expect(blocos, everyElement(isA<BlocoBolha>()));
      final antes = (blocos[0] as BlocoBolha).segmentos.single as SegmentoTexto;
      expect(antes.valor, contains('Sua grade:'));
      final depois =
          (blocos[1] as BlocoBolha).segmentos.single as SegmentoTexto;
      expect(depois.valor, contains('Depois me conta.'));
    });
  });

  group('parseReply — combinação completa', () {
    test('resposta típica do Darcy com todos os marcadores', () {
      final blocos = parseReply(
        'Para **se formar** faltam CIC0007 e mais 3.\n'
        '[TURMA|01|Edson|35T23|BT-104|10]\n'
        '[BOTAO|Ver mais|quero mais turmas]\n'
        'Qualquer coisa me chama.',
      );

      expect(blocos, hasLength(4));
      expect(blocos[0], isA<BlocoBolha>());
      expect(blocos[1], isA<BlocoTurma>());
      expect(blocos[2], isA<BlocoBotoes>());
      expect(blocos[3], isA<BlocoBolha>());

      final bolha = blocos[0] as BlocoBolha;
      expect(
        bolha.segmentos.whereType<SegmentoNegrito>().single.valor,
        'se formar',
      );
      expect(
        bolha.segmentos.whereType<SegmentoBadge>().single.codigo,
        'CIC0007',
      );
    });
  });
}
