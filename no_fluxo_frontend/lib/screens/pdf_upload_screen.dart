import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import '../utils/pdf_parser.dart';

/// Tela de exemplo para upload e parsing de PDF
/// 
/// Demonstra como integrar o PdfHistoricoParser no Flutter
class PdfUploadScreen extends StatefulWidget {
  const PdfUploadScreen({Key? key}) : super(key: key);

  @override
  State<PdfUploadScreen> createState() => _PdfUploadScreenState();
}

class _PdfUploadScreenState extends State<PdfUploadScreen> {
  bool _isLoading = false;
  PdfParseResult? _resultado;
  String? _erro;

  /// Abre seletor de arquivo e processa PDF
  Future<void> _selecionarPdf() async {
    try {
      setState(() {
        _isLoading = true;
        _erro = null;
        _resultado = null;
      });

      // 1. Seleciona arquivo PDF
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true, // Importante: carrega bytes do arquivo
      );

      if (result == null) {
        setState(() => _isLoading = false);
        return;
      }

      // 2. Obtém bytes do arquivo
      final Uint8List? pdfBytes = result.files.first.bytes;
      
      if (pdfBytes == null) {
        throw Exception('Não foi possível ler o arquivo PDF');
      }

      // 3. Faz parsing do PDF
      final resultado = await PdfHistoricoParser.parsePdf(pdfBytes);

      // 4. Atualiza estado com resultado
      setState(() {
        _resultado = resultado;
        _isLoading = false;
      });

      // 5. Opcional: Salva dados no backend
      await _enviarDadosParaBackend(resultado);

    } catch (e) {
      setState(() {
        _erro = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Envia dados extraídos para o backend
  Future<void> _enviarDadosParaBackend(PdfParseResult resultado) async {
    // TODO: Implementar chamada HTTP para seu backend
    // Exemplo:
    // final response = await http.post(
    //   Uri.parse('https://api.nofluxo.com/upload-historico'),
    //   headers: {'Content-Type': 'application/json'},
    //   body: jsonEncode(resultado.toJson()),
    // );
    
    print('Disciplinas extraídas: ${resultado.disciplinas.length}');
    print('Equivalências: ${resultado.equivalencias.length}');
    print('IRA: ${resultado.ira}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload de Histórico'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card de upload
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.upload_file,
                      size: 80,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Faça upload do seu histórico escolar',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Formato: PDF do SIGAA UnB',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _selecionarPdf,
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Selecionar PDF'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Loading
            if (_isLoading)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Processando PDF...'),
                    ],
                  ),
                ),
              ),

            // Erro
            if (_erro != null)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Erro ao processar PDF',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(_erro!),
                    ],
                  ),
                ),
              ),

            // Resultado
            if (_resultado != null) ...[
              // Dados acadêmicos
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '📊 Dados Acadêmicos',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Divider(),
                      _buildInfoRow('Curso', _resultado!.curso ?? 'N/A'),
                      _buildInfoRow('Matriz', _resultado!.matrizCurricular ?? 'N/A'),
                      _buildInfoRow('IRA', _resultado!.ira?.toStringAsFixed(4) ?? 'N/A'),
                      _buildInfoRow('MP', _resultado!.mediaPonderada?.toStringAsFixed(4) ?? 'N/A'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Disciplinas
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📚 Disciplinas (${_resultado!.disciplinas.length})',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Divider(),
                      if (_resultado!.disciplinas.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Nenhuma disciplina encontrada'),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _resultado!.disciplinas.length > 5 
                              ? 5 
                              : _resultado!.disciplinas.length,
                          itemBuilder: (context, index) {
                            final disc = _resultado!.disciplinas[index];
                            return ListTile(
                              leading: CircleAvatar(
                                child: Text(disc.mencao ?? '-'),
                                backgroundColor: _getMencaoColor(disc.mencao),
                              ),
                              title: Text(disc.nome),
                              subtitle: Text('${disc.codigo} • ${disc.status}'),
                              trailing: Text('${disc.cargaHoraria}h'),
                            );
                          },
                        ),
                      if (_resultado!.disciplinas.length > 5)
                        TextButton(
                          onPressed: () {
                            // TODO: Navegar para tela completa de disciplinas
                          },
                          child: const Text('Ver todas as disciplinas →'),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Equivalências
              if (_resultado!.equivalencias.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🔄 Equivalências (${_resultado!.equivalencias.length})',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Divider(),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _resultado!.equivalencias.length,
                          itemBuilder: (context, index) {
                            final eq = _resultado!.equivalencias[index];
                            return ListTile(
                              title: Text('${eq.codigoCumprido} → ${eq.codigoEquivalente}'),
                              subtitle: Text(eq.nomeCumprido),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(value),
        ],
      ),
    );
  }

  Color _getMencaoColor(String? mencao) {
    switch (mencao) {
      case 'SS':
        return Colors.green.shade700;
      case 'MS':
        return Colors.green.shade400;
      case 'MM':
        return Colors.yellow.shade700;
      case 'MI':
        return Colors.orange.shade700;
      case 'II':
        return Colors.red.shade700;
      case 'SR':
        return Colors.grey.shade600;
      default:
        return Colors.grey.shade400;
    }
  }
}
