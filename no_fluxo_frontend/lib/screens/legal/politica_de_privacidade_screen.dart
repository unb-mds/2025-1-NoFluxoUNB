import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PoliticaDePrivacidadeScreen extends StatelessWidget {
  const PoliticaDePrivacidadeScreen({Key? key}) : super(key: key);

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
          'Política de Privacidade',
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
              Text(
                'Política de Privacidade',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'A sua privacidade é importante para nós. É política do NoFluxo UNB respeitar a sua privacidade em relação a qualquer informação sua que possamos coletar no site NoFluxo UNB e outros sites que possuímos e operamos.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 24),
              _buildSection(
                title: '1. Coleta de Informações',
                content:
                    'Solicitamos informações pessoais e acadêmicas apenas quando realmente precisamos delas para lhe fornecer o serviço de recomendação de disciplinas. Fazemo-lo por meios justos e legais, com o seu conhecimento e consentimento. Ao realizar o upload de documentos (como históricos escolares), você está ciente de que esses dados serão processados para fins de análise acadêmica pela nossa inteligência artificial.',
              ),
              _buildSection(
                title: '2. Uso e Retenção',
                content:
                    'Apenas retemos as informações coletadas pelo tempo necessário para fornecer o serviço solicitado. Quando armazenamos dados em nosso banco de dados (Supabase), os protegemos dentro de meios comercialmente aceitáveis para evitar perdas e roubos, bem como acesso ou divulgação não autorizados. Não compartilhamos informações de identificação pessoal publicamente ou com terceiros, exceto quando exigido por lei.',
              ),
              _buildSection(
                title: '3. Transparência e LGPD',
                content:
                    'Em conformidade com a Lei Geral de Proteção de Dados (LGPD), você possui o direito de acessar, corrigir ou solicitar a exclusão de seus dados a qualquer momento. O NoFluxo UNB é um projeto Open Source, e nosso código-fonte está disponível para auditoria pública, garantindo total transparência sobre como tratamos seus dados.',
              ),
              _buildSection(
                title: '4. Cookies e Publicidade',
                content:
                    'O serviço Google AdSense usa um cookie DoubleClick para veicular anúncios mais relevantes e limitar a frequência de exibição.\n\nUtilizamos anúncios para compensar os custos de infraestrutura e desenvolvimento do projeto.\n\nVocê é livre para recusar a nossa solicitação de informações ou cookies, entendendo que talvez não possamos fornecer alguns dos serviços desejados.',
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
