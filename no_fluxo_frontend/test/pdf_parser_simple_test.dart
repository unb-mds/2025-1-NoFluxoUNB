import 'dart:io';
import 'dart:typed_data';
import '../lib/utils/pdf_parser.dart';

/// Teste simples sem depender de flutter_test
void main() async {
  print('🧪 Iniciando teste do PDF Parser...\n');
  
  try {
    // 1. Carrega PDF de teste
    final file = File('test/fixtures/historico_teste.pdf');
    
    if (!file.existsSync()) {
      print('❌ ERRO: PDF não encontrado em test/fixtures/historico_teste.pdf');
      print('   Copie seu PDF para essa pasta primeiro!');
      exit(1);
    }
    
    print('✅ PDF encontrado: ${file.lengthSync()} bytes');
    
    // 2. Lê bytes do arquivo
    final Uint8List bytes = await file.readAsBytes();
    print('✅ Bytes carregados: ${bytes.length}');
    
    // 3. Faz parsing
    print('\n⏳ Processando PDF...\n');
    final resultado = await PdfHistoricoParser.parsePdf(bytes);
    
    // 4. Mostra resultados
    print('═══════════════════════════════════════');
    print('📊 RESULTADOS DO TESTE');
    print('═══════════════════════════════════════\n');
    
    print('🎓 Curso: ${resultado.curso ?? "N/A"}');
    print('📚 Matriz: ${resultado.matrizCurricular ?? "N/A"}');
    print('📈 IRA: ${resultado.ira?.toStringAsFixed(4) ?? "N/A"}');
    print('📊 MP: ${resultado.mediaPonderada?.toStringAsFixed(4) ?? "N/A"}');
    print('🕐 Semestre Atual: ${resultado.semestreAtual ?? "N/A"}');
    print('📅 Número de Semestres: ${resultado.numeroSemestre ?? "N/A"}');
    
    print('\n───────────────────────────────────────');
    print('📚 DISCIPLINAS: ${resultado.disciplinas.length}');
    print('───────────────────────────────────────');
    
    if (resultado.disciplinas.isEmpty) {
      print('❌ NENHUMA DISCIPLINA EXTRAÍDA!');
      print('   Isso indica um problema no parser.');
    } else {
      // Mostra primeiras 5 disciplinas
      final maxShow = resultado.disciplinas.length > 5 ? 5 : resultado.disciplinas.length;
      
      for (int i = 0; i < maxShow; i++) {
        final disc = resultado.disciplinas[i];
        print('\n${i + 1}. ${disc.nome}');
        print('   Código: ${disc.codigo}');
        print('   Período: ${disc.anoPeriodo}');
        print('   Status: ${disc.status} | Menção: ${disc.mencao ?? "-"}');
        print('   CH: ${disc.cargaHoraria}h | Turma: ${disc.turma ?? "-"}');
        if (disc.frequencia != null) {
          print('   Frequência: ${disc.frequencia!.toStringAsFixed(1)}%');
        }
        if (disc.professor != null && disc.professor!.isNotEmpty) {
          print('   Professor: ${disc.professor}');
        }
      }
      
      if (resultado.disciplinas.length > 5) {
        print('\n... e mais ${resultado.disciplinas.length - 5} disciplinas');
      }
    }
    
    // Equivalências
    if (resultado.equivalencias.isNotEmpty) {
      print('\n───────────────────────────────────────');
      print('🔄 EQUIVALÊNCIAS: ${resultado.equivalencias.length}');
      print('───────────────────────────────────────');
      
      for (final eq in resultado.equivalencias) {
        print('\n${eq.codigoCumprido} → ${eq.codigoEquivalente}');
        print('   ${eq.nomeCumprido}');
        print('   (${eq.cargaHorariaCumprida}h → ${eq.cargaHorariaEquivalente}h)');
      }
    }
    
    // Suspensões
    if (resultado.suspensoes.isNotEmpty) {
      print('\n───────────────────────────────────────');
      print('⚠️  SUSPENSÕES: ${resultado.suspensoes.join(", ")}');
      print('───────────────────────────────────────');
    }
    
    // Validações
    print('\n═══════════════════════════════════════');
    print('✅ VALIDAÇÕES');
    print('═══════════════════════════════════════\n');
    
    bool sucesso = true;
    
    if (resultado.curso == null || resultado.curso!.isEmpty) {
      print('⚠️  Curso não extraído');
      sucesso = false;
    } else {
      print('✅ Curso extraído');
    }
    
    if (resultado.disciplinas.isEmpty) {
      print('❌ FALHA: Nenhuma disciplina extraída!');
      sucesso = false;
    } else {
      print('✅ ${resultado.disciplinas.length} disciplinas extraídas');
    }
    
    if (resultado.ira != null && resultado.ira! > 0) {
      print('✅ IRA válido: ${resultado.ira!.toStringAsFixed(4)}');
    } else {
      print('⚠️  IRA não extraído ou inválido');
    }
    
    // Valida estrutura de disciplinas
    if (resultado.disciplinas.isNotEmpty) {
      final disc = resultado.disciplinas.first;
      
      if (disc.codigo.isEmpty) {
        print('❌ FALHA: Código de disciplina vazio');
        sucesso = false;
      } else {
        print('✅ Códigos de disciplina válidos');
      }
      
      if (disc.nome.isEmpty) {
        print('❌ FALHA: Nome de disciplina vazio');
        sucesso = false;
      } else {
        print('✅ Nomes de disciplina válidos');
      }
      
      if (!RegExp(r'^\d{4}\.\d$').hasMatch(disc.anoPeriodo)) {
        print('⚠️  Formato de ano/período pode estar incorreto: ${disc.anoPeriodo}');
      } else {
        print('✅ Formato ano/período válido');
      }
    }
    
    print('\n═══════════════════════════════════════');
    if (sucesso) {
      print('🎉 TESTE PASSOU! Parser funcionando corretamente!');
    } else {
      print('❌ TESTE FALHOU! Verifique os erros acima.');
    }
    print('═══════════════════════════════════════\n');
    
    exit(sucesso ? 0 : 1);
    
  } catch (e, stackTrace) {
    print('\n❌ ERRO DURANTE O TESTE:');
    print(e);
    print('\nStack trace:');
    print(stackTrace);
    exit(1);
  }
}
