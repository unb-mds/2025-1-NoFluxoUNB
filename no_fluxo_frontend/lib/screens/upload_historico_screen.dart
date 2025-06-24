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
                    onWillAccept: (data) {
                      setState(() => _isDragging = true);
                      return true;
                    },
                    onLeave: (data) => setState(() => _isDragging = false),
                    onAccept: (data) {
                      setState(() {
                        _fileName = data.name;
                        _isDragging = false;
                      });
                      // TODO: processar o arquivo
                    },
                    builder: (context, candidateData, rejectedData) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: _isDragging
                                ? Colors.blue
                                : Colors.white.withOpacity(0.5),
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
                      onPressed: () {
                        // TODO: abrir modal ou página de ajuda
                      },
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
