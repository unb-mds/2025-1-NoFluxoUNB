import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../widgets/app_navbar.dart';
import '../widgets/animated_background.dart';

class UploadHistoricoScreen extends StatefulWidget {
  const UploadHistoricoScreen({Key? key}) : super(key: key);

  @override
  State<UploadHistoricoScreen> createState() => _UploadHistoricoScreenState();
}

class _UploadHistoricoScreenState extends State<UploadHistoricoScreen> {
  String? _fileName;
  bool _isDragging = false;

  void _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'html'],
    );
    if (result != null) {
      setState(() {
        _fileName = result.files.single.name;
      });
      // TODO: processar o arquivo
    }
  }

  void _showHelpModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 700,
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header com título e botão de fechar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(
                          child: Text(
                            'Como obter seu histórico acadêmico',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A202C),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close,
                              color: Colors.grey[500], size: 28),
                          onPressed: () => Navigator.of(context).pop(),
                          splashRadius: 22,
                          tooltip: 'Fechar',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Passo 1
                    const _PassoHistorico(
                      titulo: '1º PASSO - Acesse o SIGAA',
                      descricao: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: 'Entre no '),
                            TextSpan(
                              text: 'SIGAA',
                              style: TextStyle(
                                color: Color(0xFF2563EB),
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            TextSpan(
                                text: ' com seu login e senha institucional.'),
                          ],
                          style:
                              TextStyle(color: Color(0xFF1A202C), fontSize: 16),
                        ),
                      ),
                      imagem: 'assets/help/tela_de_cadastro.png',
                      alt: 'Tela de login do SIGAA',
                    ),
                    // Passo 2
                    const _PassoHistorico(
                      titulo: '2º PASSO - Selecione "Emitir Histórico"',
                      descricao: Text(
                        'No menu lateral, clique em Ensino e depois em Emitir Histórico.',
                        style:
                            TextStyle(fontSize: 16, color: Color(0xFF1A202C)),
                      ),
                      imagem: 'assets/help/emitir_historico.png',
                      alt: 'Menu Emitir Histórico no SIGAA',
                    ),
                    // Passo 3
                    const _PassoHistorico(
                      titulo:
                          '3º PASSO - Faça o upload do PDF para o NoFluxoUNB',
                      descricao: Text(
                        'Salve o arquivo PDF gerado em seu computador e faça o upload nesta página.',
                        style:
                            TextStyle(fontSize: 16, color: Color(0xFF1A202C)),
                      ),
                      imagem: 'assets/help/historico_baixado.png',
                      alt: 'Exemplo de histórico acadêmico gerado',
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B469B),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Entendi',
                            style:
                                TextStyle(color: Colors.white, fontSize: 18)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Fundo animado com círculos coloridos borrados
          const AnimatedBackground(),
          SafeArea(
            child: Column(
              children: [
                // Navbar padrão
                const AppNavbar(),
                const Spacer(),
                // Card central
                Center(
                  child: DragTarget<PlatformFile>(
                    onWillAcceptWithDetails: (data) {
                      setState(() => _isDragging = true);
                      return true;
                    },
                    onLeave: (data) => setState(() => _isDragging = false),
                    onAcceptWithDetails: (data) {
                      setState(() {
                        _fileName = data.data.name;
                        _isDragging = false;
                      });
                      // TODO: processar o arquivo
                    },
                    builder: (context, candidateData, rejectedData) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5 * 255),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: _isDragging
                                ? Colors.blue
                                : Colors.white.withValues(alpha: 0.5 * 255),
                            width: 2,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cloud_upload,
                                color: Colors.white, size: 64),
                            const SizedBox(height: 24),
                            Text(
                              _fileName == null
                                  ? 'Arraste seu histórico acadêmico aqui'
                                  : 'Arquivo selecionado: [4m${_fileName ?? ''}[0m',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            const Text('ou',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 16)),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: 240,
                              child: ElevatedButton.icon(
                                onPressed: _pickFile,
                                icon: const Icon(Icons.upload_file,
                                    color: Colors.white),
                                label: const Text('Selecionar Histórico',
                                    style: TextStyle(
                                        fontSize: 18, color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Formatos aceitos: PDF, DOC, DOCX, TXT, HTML',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 14),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 32),
                // Botão de ajuda
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF9333EA), Color(0xFFFBBF24)]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TextButton.icon(
                      onPressed: _showHelpModal,
                      icon: const Icon(Icons.help_outline, color: Colors.black),
                      label: const Text(
                        'Como obter seu histórico acadêmico?',
                        style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 18),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 8),
                        backgroundColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PassoHistorico extends StatelessWidget {
  final String titulo;
  final Widget descricao;
  final String imagem;
  final String alt;

  const _PassoHistorico({
    required this.titulo,
    required this.descricao,
    required this.imagem,
    required this.alt,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Color(0xFF1A202C),
            ),
          ),
          const SizedBox(height: 6),
          descricao,
          const SizedBox(height: 12),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: (0.08 * 255)),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Image.asset(
                  imagem,
                  width: 400,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[200],
                    width: 400,
                    height: 180,
                    alignment: Alignment.center,
                    child: Text(
                      'Imagem não encontrada:\n$imagem',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
