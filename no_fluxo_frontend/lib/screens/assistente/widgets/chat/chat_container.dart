import 'package:flutter/material.dart';
import 'chat_message.dart';
import 'chat_input.dart';
import 'typing_indicator.dart';

class ChatContainer extends StatefulWidget {
  const ChatContainer({Key? key}) : super(key: key);

  @override
  State<ChatContainer> createState() => _ChatContainerState();
}

class _ChatContainerState extends State<ChatContainer> {
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _addWelcomeMessage();
  }

  void _addWelcomeMessage() {
    _messages.add(
      const ChatMessage(
        text:
            'Olá! Sou o assistente NoFluxo. Estou aqui para te ajudar a encontrar matérias interessantes para adicionar ao seu fluxograma.',
        isBot: true,
      ),
    );
    _messages.add(
      const ChatMessage(
        text:
            'Me conte quais áreas você tem interesse ou quais habilidades gostaria de desenvolver!',
        isBot: true,
      ),
    );
  }

  void _addMessage(String text, {bool isBot = false}) {
    setState(() {
      _messages.add(ChatMessage(text: text, isBot: isBot));
    });

    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showTypingIndicator() {
    setState(() {
      _isTyping = true;
    });
  }

  void _hideTypingIndicator() {
    setState(() {
      _isTyping = false;
    });
  }

  void _handleSendMessage(String message) {
    if (message.trim().isEmpty) return;

    _addMessage(message, isBot: false);
    _showTypingIndicator();

    // Simular resposta do bot
    Future.delayed(const Duration(seconds: 2), () {
      _hideTypingIndicator();
      _addMessage('Entendi! Vou te ajudar com isso.', isBot: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Chat Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ASSISTENTE NOFLUXO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Online',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return const TypingIndicator();
                }
                return _messages[index];
              },
            ),
          ),

          // Input
          ChatInput(onSend: _handleSendMessage),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
