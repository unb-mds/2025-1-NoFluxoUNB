import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SobreNosSection extends StatelessWidget {
  const SobreNosSection({super.key});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 0),
      color: Colors.black.withOpacity(0.5),
      child: Column(
        children: [
          Text(
            'SOBRE NÓS',
            style: GoogleFonts.permanentMarker(
              color: Colors.white,
              fontSize: 32,
              letterSpacing: 1.5,
              shadows: const [
                Shadow(
                  color: Color.fromARGB(120, 0, 0, 0),
                  offset: Offset(2, 2),
                  blurRadius: 4,
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          // Card de descrição
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: _AnimatedSobreNosCard(),
            ),
          ),
          // Cards dos membros
          _membrosGrid(isWide),
        ],
      ),
    );
  }

  Widget _featureItem(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: SvgPicture.string(
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="16" height="16"><path stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" fill="none" d="M5 13l4 4L19 7"/></svg>',
              ),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: RichText(
              textAlign: TextAlign.left,
              text: TextSpan(
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 15,
                ),
                children: [
                  TextSpan(
                      text: title,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: ' $desc'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _membrosGrid(bool isWide) {
    final membros = [
      _membroCard(
          'Guilherme Gusmão', 'https://avatars.githubusercontent.com/gusmoles'),
      _membroCard('Vitor Marconi',
          'https://avatars.githubusercontent.com/Vitor-Trancoso'),
      _membroCard(
          'Gustavo Choueiri', 'https://avatars.githubusercontent.com/staann'),
      _membroCard(
          'Felipe Lopes', 'https://avatars.githubusercontent.com/darkymeubem'),
      _membroCard('Vinícius Pereira',
          'https://avatars.githubusercontent.com/Vinicius-Ribeiro04'),
      _membroCard(
          'Arthur Fernandes', 'https://avatars.githubusercontent.com/hisarxt'),
      _membroCard(
          'Erick Alves', 'https://avatars.githubusercontent.com/erickaalves'),
      _membroCard('Arthur Ramalho',
          'https://avatars.githubusercontent.com/ArthurNRamalho'),
    ];
    final screenWidth = WidgetsBinding.instance.window.physicalSize.width /
        WidgetsBinding.instance.window.devicePixelRatio;
    final isMobile = screenWidth < 700;
    if (isMobile) {
      // Em mobile, 4 linhas com 2 integrantes por linha, alinhados em altura
      List<Widget> linhas = [];
      for (int i = 0; i < membros.length; i += 2) {
        linhas.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: IntrinsicHeight(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(child: membros[i]),
                  const SizedBox(width: 8),
                  Expanded(child: membros[i + 1]),
                ],
              ),
            ),
          ),
        );
      }
      return Column(children: linhas);
    }
    // Desktop/tablet: mantém o layout original
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 24,
          runSpacing: 24,
          children: membros.take(4).toList(),
        ),
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 24,
          runSpacing: 24,
          children: membros.skip(4).toList(),
        ),
      ],
    );
  }

  Widget _membroCard(String nome, String githubUrl) {
    return MembroCard(nome: nome, githubUrl: githubUrl);
  }
}

class MembroCard extends StatefulWidget {
  final String nome;
  final String githubUrl;

  const MembroCard({
    super.key,
    required this.nome,
    required this.githubUrl,
  });

  @override
  State<MembroCard> createState() => _MembroCardState();
}

class _MembroCardState extends State<MembroCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 700;
    final cardSize = isMobile ? 180.0 : 280.0;
    final imageSize = isMobile ? 100.0 : 100.0;
    final nameFontSize = isMobile ? 18.0 : 22.0;
    final roleFontSize = isMobile ? 14.0 : 16.0;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        child: Container(
          width: cardSize,
          // Altura dinâmica em mobile, fixa só no desktop
          constraints: isMobile
              ? BoxConstraints(minHeight: 200)
              : BoxConstraints.tightFor(height: cardSize),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: imageSize,
                height: imageSize,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(imageSize / 2),
                  child: Image.network(
                    widget.githubUrl,
                    width: imageSize,
                    height: imageSize,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        width: imageSize,
                        height: imageSize,
                        color: Colors.grey[800],
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: imageSize,
                        height: imageSize,
                        color: Colors.grey[800],
                        child: const Icon(Icons.person,
                            size: 30, color: Colors.white),
                      );
                    },
                  ),
                ),
              ),
              SizedBox(height: isMobile ? 12 : 24),
              Text(
                widget.nome,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: nameFontSize,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'PermanentMarker',
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: isMobile ? 4 : 8),
              Text(
                'Desenvolvedor',
                style: GoogleFonts.poppins(
                  color: const Color.fromARGB(255, 174, 173, 173),
                  fontSize: roleFontSize,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedSobreNosCard extends StatefulWidget {
  @override
  State<_AnimatedSobreNosCard> createState() => _AnimatedSobreNosCardState();
}

class _AnimatedSobreNosCardState extends State<_AnimatedSobreNosCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 700;
    final cardPadding = isMobile ? 16.0 : 32.0;
    final mainFontSize = isMobile ? 13.0 : 18.0;
    final featureFontSize = isMobile ? 11.0 : 15.0;
    final maxCardWidth = isMobile ? screenWidth - 32 : 1200.0;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxCardWidth),
            child: Container(
              margin: const EdgeInsets.only(bottom: 32),
              padding: EdgeInsets.all(cardPadding),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  RichText(
                    textAlign: TextAlign.justify,
                    text: TextSpan(
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: mainFontSize,
                      ),
                      children: const [
                        TextSpan(
                            text:
                                'O NoFluxoUnB é criado na disciplina de Métodos de Desenvolvimento de Software ministrada pela professora Carla Rocha, com a proposta de desenvolver um software inovador para a comunidade. Nossa proposta foi desenvolver um software que facilita o planejamento acadêmico dos estudantes da UnB, oferecendo um fluxograma interativo, intuitivo e de fácil uso. Visualize matérias equivalentes, selecione disciplinas futuras e receba recomendações personalizadas com inteligência artificial.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.chat_bubble_outline,
                          color: Colors.white70, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Observação: ',
                        style: GoogleFonts.poppins(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: isMobile ? 11.0 : 14.0,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          'Inicialmente disponível para cursos da FGA/UnB, com perspectiva de expansão!',
                          style: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: isMobile ? 11.0 : 14.0,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _featureItem(
                            'UX moderna:',
                            'Interface visual clara, responsiva e fácil de navegar.',
                            featureFontSize),
                        _featureItem(
                            'Inteligência Artificial:',
                            'Sugestão de disciplinas alinhadas aos interesses do estudante.',
                            featureFontSize),
                        _featureItem(
                            'Personalização:',
                            'Planejamento acadêmico inteligente e eficiente, adaptado ao perfil do aluno.',
                            featureFontSize),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _featureItem(String title, String desc, double fontSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 700;
    final maxTextWidth = isMobile ? screenWidth - 80 : 800.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.check, color: Colors.white, size: 18),
            ),
          ),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxTextWidth),
              child: RichText(
                textAlign: TextAlign.left,
                text: TextSpan(
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: fontSize,
                  ),
                  children: [
                    TextSpan(
                        text: title,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(text: ' $desc'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
