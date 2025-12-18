import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../utils/pdf_parser.dart';

/// Tela de teste do parser de PDF
/// Permite selecionar um PDF e visualizar os dados extraídos
class TestPdfParserScreen extends StatefulWidget {
  const TestPdfParserScreen({Key? key}) : super(key: key);

  @override
  State<TestPdfParserScreen> createState() => _TestPdfParserScreenState();
}

class _TestPdfParserScreenState extends State<TestPdfParserScreen> {
  PdfParseResult? _resultado;
  bool _carregando = false;
  String? _erro;
  String? _nomeArquivo;

  Future<void> _selecionarPdf() async {
    try {
      setState(() {
        _carregando = true;
        _erro = null;
        _resultado = null;
      });

      // Abre seletor de arquivo
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true, // Importante: carrega bytes do arquivo
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _carregando = false);
        return;
      }

      final file = result.files.first;
      _nomeArquivo = file.name;

      // Lê bytes do PDF
      final bytes = file.bytes ?? await File(file.path!).readAsBytes();

      // Faz parsing
      final resultado = await PdfParser.parsePdf(bytes);

      setState(() {
        _resultado = resultado;
        _carregando = false;
      });
    } catch (e) {
      setState(() {
        _erro = 'Erro ao processar PDF: $e';
        _carregando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teste: Parser de PDF'),
        backgroundColor: Colors.blue,
      ),
      body: _carregando
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Processando PDF...'),
                ],
              ),
            )
          : _resultado == null
              ? _buildTelaInicial()
              : _buildResultado(),
    );
  }

  Widget _buildTelaInicial() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.picture_as_pdf,
            size: 100,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 24),
          const Text(
            'Selecione um PDF de histórico escolar',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Formato SIGAA - UnB',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _selecionarPdf,
            icon: const Icon(Icons.upload_file),
            label: const Text('Escolher PDF'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              textStyle: const TextStyle(fontSize: 16),
            ),
          ),
          if (_erro != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: Colors.red[50],
                border: Border.all(color: Colors.red),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _erro!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultado() {
    final resultado = _resultado!;
    final disciplinasAprovadas = resultado.disciplinas
        .where((d) => d.status == 'APR')
        .toList();
    final disciplinasMatriculadas = resultado.disciplinas
        .where((d) => d.status == 'MATR')
        .toList();
    final disciplinasReprovadas = resultado.disciplinas
        .where((d) => d.status == 'REP' || d.status == 'REPF' || d.status == 'REPMF')
        .toList();
    final disciplinasPendentes = resultado.disciplinas
        .where((d) => d.status == 'PENDENTE')
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PDF Processado com Sucesso!',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    if (_nomeArquivo != null)
                      Text(
                        _nomeArquivo!,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _selecionarPdf,
                icon: const Icon(Icons.refresh),
                label: const Text('Novo PDF'),
              ),
            ],
          ),
          const Divider(height: 32),

          // Cards de resumo
          Row(
            children: [
              Expanded(
                child: _buildCardResumo(
                  'Curso',
                  resultado.curso ?? 'N/A',
                  Icons.school,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildCardResumo(
                  'IRA',
                  resultado.ira?.toStringAsFixed(4) ?? 'N/A',
                  Icons.star,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildCardResumo(
                  'Total Disciplinas',
                  '${resultado.disciplinas.length}',
                  Icons.list,
                  Colors.purple,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildCardResumo(
                  'Equivalências',
                  '${resultado.equivalencias.length}',
                  Icons.compare_arrows,
                  Colors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Tabs de disciplinas
          DefaultTabController(
            length: 4,
            child: Column(
              children: [
                TabBar(
                  labelColor: Colors.blue,
                  unselectedLabelColor: Colors.grey,
                  tabs: [
                    Tab(text: 'Aprovadas (${disciplinasAprovadas.length})'),
                    Tab(text: 'Cursando (${disciplinasMatriculadas.length})'),
                    Tab(text: 'Reprovadas (${disciplinasReprovadas.length})'),
                    Tab(text: 'Pendentes (${disciplinasPendentes.length})'),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 400,
                  child: TabBarView(
                    children: [
                      _buildListaDisciplinas(disciplinasAprovadas, Colors.green),
                      _buildListaDisciplinas(disciplinasMatriculadas, Colors.blue),
                      _buildListaDisciplinas(disciplinasReprovadas, Colors.red),
                      _buildListaDisciplinas(disciplinasPendentes, Colors.grey),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Equivalências
          if (resultado.equivalencias.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Equivalências',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...resultado.equivalencias.map((eq) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.compare_arrows, color: Colors.teal),
                title: Text('${eq.codigoCumprido} → ${eq.codigoEquivalente}'),
                subtitle: Text(
                  '${eq.nomeCumprido}\n⬇️\n${eq.nomeEquivalente}',
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${eq.cargaHorariaCumprida}h'),
                    Text('→ ${eq.cargaHorariaEquivalente}h'),
                  ],
                ),
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildCardResumo(String titulo, String valor, IconData icone, Color cor) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icone, color: cor, size: 32),
            const SizedBox(height: 8),
            Text(
              titulo,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(
              valor,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: cor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListaDisciplinas(List<Disciplina> disciplinas, Color cor) {
    if (disciplinas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Nenhuma disciplina nesta categoria',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: disciplinas.length,
      itemBuilder: (context, index) {
        final disc = disciplinas[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: cor.withOpacity(0.2),
              child: Text(
                disc.mencao ?? '-',
                style: TextStyle(color: cor, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              disc.codigo,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              disc.nome,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              disc.anoPeriodo.isNotEmpty ? disc.anoPeriodo : '-',
              style: TextStyle(color: Colors.grey[600]),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetalhe('Nome completo', disc.nome),
                    _buildDetalhe('Código', disc.codigo),
                    _buildDetalhe('Status', disc.status),
                    _buildDetalhe('Menção', disc.mencao ?? 'N/A'),
                    _buildDetalhe('Ano/Período', disc.anoPeriodo.isNotEmpty ? disc.anoPeriodo : 'N/A'),
                    if (disc.turma != null)
                      _buildDetalhe('Turma', disc.turma!),
                    if (disc.cargaHoraria != null)
                      _buildDetalhe('Carga Horária', '${disc.cargaHoraria}h'),
                    if (disc.frequencia != null)
                      _buildDetalhe('Frequência', '${disc.frequencia}%'),
                    if (disc.professor != null)
                      _buildDetalhe('Professor', disc.professor!),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetalhe(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
