import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/app_navbar.dart';
import '../../widgets/graffiti_background.dart';

class AssistenteScreen extends StatefulWidget {
  const AssistenteScreen({Key? key}) : super(key: key);

  @override
  State<AssistenteScreen> createState() => _AssistenteScreenState();
}

class _AssistenteScreenState extends State<AssistenteScreen> {
  final TextEditingController _chatController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [
    {
      'isUser': false,
      'text':
          'Olá! Sou o assistente NoFluxo. Estou aqui para te ajudar a encontrar matérias interessantes para adicionar ao seu fluxograma.\nMe conte quais áreas você tem interesse ou quais habilidades gostaria de desenvolver!'
    }
  ];
  final List<String> _interestTags = [
    'Programação',
    'Dados',
    'Design',
    'Gestão',
    'Pesquisa',
    'Inovação'
  ];
  final List<String> _selectedInterests = [];
  final List<String> _selectedCourses = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      body: Stack(
        children: [
          const GraffitiBackground(),
          Column(
            children: [
              const AppNavbar(),
              Expanded(
                child: SafeArea(
                  child: Row(
                    children: [
                      // Chat principal
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header do chat
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'ASSISTENTE ',
                                    style: GoogleFonts.permanentMarker(
                                      color: Colors.white,
                                      fontSize: 28,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: const BoxDecoration(
                                          color: Colors.green,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text('Online',
                                          style: TextStyle(
                                              color: Colors.white, fontSize: 14)),
                                    ],
                                  )
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Mensagens do chat
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: ListView.builder(
                                    itemCount: _messages.length,
                                    itemBuilder: (context, index) {
                                      final msg = _messages[index];
                                      return Align(
                                        alignment: msg['isUser']
                                            ? Alignment.centerRight
                                            : Alignment.centerLeft,
                                        child: Container(
                                          margin: const EdgeInsets.symmetric(
                                              vertical: 8, horizontal: 12),
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: msg['isUser']
                                                ? null
                                                : Colors.white.withOpacity(0.1),
                                            gradient: msg['isUser']
                                                ? const LinearGradient(colors: [
                                                    Color(0xFF4A1D96),
                                                    Color(0xFF8B5CF6)
                                                  ])
                                                : null,
                                            borderRadius: BorderRadius.only(
                                              topLeft: msg['isUser']
                                                  ? const Radius.circular(16)
                                                  : Radius.zero,
                                              topRight: msg['isUser']
                                                  ? Radius.zero
                                                  : const Radius.circular(16),
                                              bottomLeft: const Radius.circular(16),
                                              bottomRight: const Radius.circular(16),
                                            ),
                                          ),
                                          child: Text(
                                            msg['text'],
                                            style: const TextStyle(color: Colors.white),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Tags de interesse
                              Wrap(
                                spacing: 8,
                                children: _interestTags.map((tag) {
                                  final selected = _selectedInterests.contains(tag);
                                  return ChoiceChip(
                                    label: Text(tag,
                                        style: const TextStyle(color: Colors.white)),
                                    selected: selected,
                                    selectedColor: Colors.purple,
                                    backgroundColor: Colors.grey[800],
                                    onSelected: (val) {
                                      setState(() {
                                        if (selected) {
                                          _selectedInterests.remove(tag);
                                        } else {
                                          _selectedInterests.add(tag);
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 12),
                              // Campo de input
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _chatController,
                                      style: const TextStyle(color: Colors.white),
                                      decoration: InputDecoration(
                                        hintText: 'Digite sua mensagem...',
                                        hintStyle: TextStyle(color: Colors.white54),
                                        filled: true,
                                        fillColor: Colors.grey[900],
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(30),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                      onSubmitted: (value) {
                                        if (value.trim().isNotEmpty) {
                                          setState(() {
                                            _messages.add(
                                                {'isUser': true, 'text': value.trim()});
                                            _chatController.clear();
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.send, color: Colors.white),
                                    onPressed: () {
                                      final value = _chatController.text.trim();
                                      if (value.isNotEmpty) {
                                        setState(() {
                                          _messages.add({'isUser': true, 'text': value});
                                          _chatController.clear();
                                        });
                                      }
                                    },
                                  )
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Painel lateral
                      Expanded(
                        flex: 1,
                        child: Container(
                          margin: const EdgeInsets.only(top: 24, bottom: 24, right: 24),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Matérias Selecionadas',
                                  style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              Expanded(
                                child: _selectedCourses.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.menu_book,
                                                color: Colors.white24, size: 48),
                                            const SizedBox(height: 8),
                                            const Text('Nenhuma matéria selecionada',
                                                style: TextStyle(color: Colors.white38)),
                                          ],
                                        ),
                                      )
                                    : ListView(
                                        children: _selectedCourses.map((course) => ListTile(
                                              title: Text(course,
                                                  style: const TextStyle(
                                                      color: Colors.white)),
                                              trailing: IconButton(
                                                icon: const Icon(Icons.close,
                                                    color: Colors.white54),
                                                onPressed: () {
                                                  setState(() {
                                                    _selectedCourses.remove(course);
                                                  });
                                                },
                                              ),
                                            )).toList(),
                              ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF8B5CF6),
                                  minimumSize: const Size.fromHeight(48),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () {},
                                child: const Text('ADICIONAR AO FLUXOGRAMA',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
