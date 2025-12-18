import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/utils/pdf_parser.dart';

void main() {
  group('PdfParser Tests', () {
    
    test('Deve extrair disciplinas de PDF válido', () async {
      // 1. Carrega PDF de teste (coloque seu PDF na pasta test/fixtures/)
      final file = File('test/fixtures/historico_teste.pdf');
      
      if (!file.existsSync()) {
        print('⚠️ Coloque um PDF de teste em: test/fixtures/historico_teste.pdf');
        return;
      }
      
      final bytes = await file.readAsBytes();
      
      // 2. Faz parsing
      final resultado = await PdfParser.parsePdf(bytes);
      
      // 3. Validações
      expect(resultado, isNotNull);
      expect(resultado.disciplinas, isNotEmpty, reason: 'Deve extrair pelo menos 1 disciplina');
      expect(resultado.curso, isNotNull, reason: 'Deve extrair o nome do curso');
      
      // 4. Logs para debug
      print('\n📊 Resultados do Teste:');
      print('   Curso: ${resultado.curso}');
      print('   IRA: ${resultado.ira}');
      print('   Disciplinas: ${resultado.disciplinas.length}');
      print('   Equivalências: ${resultado.equivalencias.length}');
      
      if (resultado.disciplinas.isNotEmpty) {
        print('\n📚 Primeira disciplina:');
        final disc = resultado.disciplinas.first;
        print('   ${disc.codigo} - ${disc.nome}');
        print('   Status: ${disc.status} | Menção: ${disc.mencao}');
      }
    });
    
    test('Deve validar estrutura de Disciplina', () async {
      final file = File('test/fixtures/historico_teste.pdf');
      if (!file.existsSync()) return;
      
      final bytes = await file.readAsBytes();
      final resultado = await PdfParser.parsePdf(bytes);
      
      if (resultado.disciplinas.isEmpty) return;
      
      final disc = resultado.disciplinas.first;
      
      // Valida campos obrigatórios
      expect(disc.codigo, isNotEmpty, reason: 'Código não pode ser vazio');
      expect(disc.nome, isNotEmpty, reason: 'Nome não pode ser vazio');
      expect(disc.status, isNotEmpty, reason: 'Status não pode ser vazio');
      expect(disc.anoPeriodo, matches(RegExp(r'^\d{4}\.\d$')), 
             reason: 'Ano/período deve ter formato YYYY.S');
    });
  });
}
