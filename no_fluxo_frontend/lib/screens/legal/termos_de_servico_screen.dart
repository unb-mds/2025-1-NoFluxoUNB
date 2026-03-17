import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TermosDeServicoScreen extends StatelessWidget {
  const TermosDeServicoScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Termos de Serviço',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection(
                title: '1. Aceitação dos Termos',
                content:
                    'Ao acessar ao site NoFluxo UNB, você concorda em cumprir estes termos de serviço, todas as leis e regulamentos aplicáveis e concorda que é responsável pelo cumprimento de todas as leis locais aplicáveis.',
              ),
              _buildSection(
                title: '2. Licença de Software (Open Source)',
                content:
                    'O NoFluxo UNB é software livre, distribuído sob a licença GNU GPLv3. Isso significa que - Liberdade: Você pode usar, estudar, compartilhar e modificar o software. Reciprocidade: Qualquer trabalho derivado ou cópia deste código deve, obrigatoriamente, ser mantido como software livre sob a mesma licença GPLv3. Proibição de Fechamento É estritamente proibido transformar este código em um produto proprietário/fechado ou comercializá-lo sem fornecer o código-fonte correspondente.',
              ),
              _buildSection(
                title: '3. Isenção de Responsabilidade',
                content:
                    'Os materiais no site da NoFluxo UNB são fornecidos "como estão". O NoFluxo UNB não oferece garantias, expressas ou implícitas.\n\nAtenção Acadêmica: As recomendações geradas por nossa IA e sistemas de RAG são meramente informativas. O NoFluxo UNB não garante a precisão absoluta dos dados e não substitui o aconselhamento oficial da coordenação do curso ou as regras do SIGAA/Matrícula Web da UnB. O uso das informações para fins de matrícula é de inteira responsabilidade do usuário.',
              ),
              _buildSection(
                title: '4. Limitações',
                content:
                    'Em nenhum caso o NoFluxo UNB ou seus desenvolvedores serão responsáveis por quaisquer danos (incluindo, sem limitação, danos por perda de dados, lucros ou interrupção de atividades acadêmicas) decorrentes do uso ou da incapacidade de usar os materiais no site.',
              ),
              _buildSection(
                title: '5. Precisão dos Materiais',
                content:
                    'Os materiais exibidos no site podem incluir erros técnicos, tipográficos ou de processamento de IA. O NoFluxo UNB não garante que qualquer material seja preciso, completo ou atual, embora busquemos a melhoria contínua através da comunidade.',
              ),
              _buildSection(
                title: '6. Lei Aplicável',
                content:
                    'Estes termos e condições são regidos e interpretados de acordo com as leis da República Federativa do Brasil e você se submete irrevogavelmente à jurisdição exclusiva dos tribunais em Brasília, DF.',
              ),
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(
                  'Esta política é efetiva a partir de 17 de Março de 2026.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required String content}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
