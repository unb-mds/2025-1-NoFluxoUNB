import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ToolModals {
  static void showToolModal(
    BuildContext context, {
    required String title,
    bool isAnonymous = false,
  }) {
    // Don't show tool modals for anonymous users since they require user data
    if (isAnonymous) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Faça login para acessar esta funcionalidade"),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    switch (title) {
      case 'Calculadora de IRA':
        _showIRACalculatorModal(context);
        break;
      case 'Progresso do Curso':
        _showCourseProgressModal(context);
        break;
      case 'Integralização':
        _showIntegrationModal(context);
        break;
      case 'Mudança de Curso':
        _showCourseChangeModal(context);
        break;
    }
  }

  static void _showIRACalculatorModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          backgroundColor: Colors.black.withOpacity(0.92),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520, minWidth: 400),
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Calculadora de IRA',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF818CF8),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.white54, size: 28),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Adicione as disciplinas e notas esperadas para simular seu IRA futuro.',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF818CF8),
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 18),
                // Campos de disciplina (editáveis)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Disciplina',
                            hintStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Colors.black.withOpacity(0.4),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: Color(0xFF374151)),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 70,
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Nota',
                            hintStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Colors.black.withOpacity(0.4),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: Color(0xFF374151)),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                          ),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Créditos',
                            hintStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Colors.black.withOpacity(0.4),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: Color(0xFF374151)),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                          ),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                ),
                // Botão adicionar disciplina (sem ação)
                TextButton.icon(
                  onPressed: null,
                  icon:
                      const Icon(Icons.add, color: Color(0xFF818CF8), size: 18),
                  label: Text(
                    'Adicionar disciplina',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF818CF8),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                // Card IRA
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(18),
                  margin: const EdgeInsets.only(bottom: 18),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('IRA Atual:',
                              style: GoogleFonts.poppins(
                                  color: const Color(0xFFDBEAFE),
                                  fontWeight: FontWeight.w500)),
                          Text('-',
                              style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('IRA Simulado:',
                              style: GoogleFonts.poppins(
                                  color: const Color(0xFFDBEAFE),
                                  fontWeight: FontWeight.w500)),
                          Text('-',
                              style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18)),
                        ],
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Calcular'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static void _showCourseProgressModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          backgroundColor: Colors.black.withOpacity(0.92),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 700, minWidth: 400),
            padding: const EdgeInsets.all(28),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progresso do Curso',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF60A5FA),
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.white54, size: 28),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Progresso geral
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Progresso Geral',
                                style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500)),
                            Text('0% (0/0 créditos)',
                                style: GoogleFonts.poppins(
                                    color: const Color(0xFF60A5FA),
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: const LinearProgressIndicator(
                            value: 0.0,
                            minHeight: 12,
                            backgroundColor: Color(0xFF374151),
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF2563EB)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Disciplinas por área e desempenho por área
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Disciplinas por área
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Disciplinas por Área',
                                  style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500)),
                              const SizedBox(height: 10),
                              _buildProgressBarRow('Obrigatórias',
                                  '0/0 créditos', 0.0, Colors.blue),
                              _buildProgressBarRow('Optativas', '0/0 créditos',
                                  0.0, Colors.blue),
                              _buildProgressBarRow('Complementares',
                                  '0/0 créditos', 0.0, Colors.blue),
                            ],
                          ),
                        ),
                      ),
                      // Desempenho por área
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Desempenho por Área',
                                  style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500)),
                              const SizedBox(height: 10),
                              _buildProgressBarRow(
                                  'Programação', '0.0', 0.0, Colors.green),
                              _buildProgressBarRow(
                                  'Matemática', '0.0', 0.0, Colors.green),
                              _buildProgressBarRow(
                                  'Engenharia', '0.0', 0.0, Colors.green),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Histórico de IRA por semestre (área para gráfico)
                  Text('Histórico de IRA por Semestre',
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    height: 180,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Gráfico em breve...',
                      style: GoogleFonts.poppins(
                          color: Colors.white38,
                          fontSize: 16,
                          fontStyle: FontStyle.italic),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 22, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Fechar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static void _showIntegrationModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          backgroundColor: Colors.black.withOpacity(0.92),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 700, minWidth: 400),
            padding: const EdgeInsets.all(28),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Integralização Curricular',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF22C55E),
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.white54, size: 28),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // Card de previsão de formatura
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF14532D),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 24),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            color: Color(0xFF22C55E), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Previsão de formatura: ',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF22C55E),
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '2º semestre de 2023',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF22C55E),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Título dos requisitos
                  Text(
                    'Requisitos para Integralização',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Créditos Obrigatórios
                  _buildRequirementCard(
                    'Créditos Obrigatórios',
                    '0/160 créditos (0%)',
                    0.0,
                    'Faltam 160 créditos em disciplinas obrigatórias.',
                  ),
                  const SizedBox(height: 12),
                  // Créditos Optativos
                  _buildRequirementCard(
                    'Créditos Optativos',
                    '0/40 créditos (0%)',
                    0.0,
                    'Faltam 40 créditos em disciplinas optativas.',
                  ),
                  const SizedBox(height: 12),
                  // Atividades Complementares
                  _buildRequirementCard(
                    'Atividades Complementares',
                    '0/40 horas (0%)',
                    0.0,
                    'Faltam 40 horas de atividades complementares.',
                  ),
                  const SizedBox(height: 12),
                  // TCC
                  _buildTCCCard(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF22C55E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 22, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Fechar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static void _showCourseChangeModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          backgroundColor: Colors.black.withOpacity(0.92),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 700, minWidth: 400),
            padding: const EdgeInsets.all(28),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Simulação de Mudança de Curso',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFFF59E0B),
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.white54, size: 28),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Selecione um curso para simular o aproveitamento de disciplinas e créditos.',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFF59E0B),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Dropdown de seleção de curso
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Curso de Destino',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFFF59E0B),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF374151)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonFormField<String>(
                          value: null,
                          decoration: const InputDecoration(
                            hintText: 'Selecione um curso',
                            hintStyle: TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Colors.black,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            border: InputBorder.none,
                          ),
                          dropdownColor: Colors.black,
                          style: const TextStyle(color: Colors.white),
                          items: const [
                            DropdownMenuItem(
                                value: 'cc',
                                child: Text('Ciência da Computação')),
                            DropdownMenuItem(
                                value: 'si',
                                child: Text('Sistemas de Informação')),
                            DropdownMenuItem(
                                value: 'ec',
                                child: Text('Engenharia da Computação')),
                            DropdownMenuItem(
                                value: 'ads',
                                child: Text(
                                    'Análise e Desenvolvimento de Sistemas')),
                          ],
                          onChanged: (value) {
                            // TODO: Implementar lógica de simulação
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Resultados da simulação (inicialmente ocultos)
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF92400E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Resumo do Aproveitamento',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFF59E0B),
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    '-',
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFFFCD34D),
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Aproveitamento',
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFFF59E0B),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    '-',
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFFFCD34D),
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Créditos aproveitados',
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFFF59E0B),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    '-',
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFFFCD34D),
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Semestres adicionais',
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFFF59E0B),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Disciplinas aproveitadas
                  _buildSubjectListCard(
                    'Disciplinas Aproveitadas',
                    [],
                    isApproved: true,
                  ),
                  const SizedBox(height: 12),
                  // Disciplinas adicionais necessárias
                  _buildSubjectListCard(
                    'Disciplinas Adicionais Necessárias',
                    [],
                    isApproved: false,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 22, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: Color(0xFF374151)),
                          ),
                        ),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 22, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Simular'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Helper para barra de progresso customizada
  static Widget _buildProgressBarRow(
      String label, String value, double percent, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style:
                      GoogleFonts.poppins(color: Colors.white, fontSize: 14)),
              Text(value,
                  style:
                      GoogleFonts.poppins(color: Colors.white, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 8,
              backgroundColor: const Color(0xFF374151),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  // Helper para card de requisito
  static Widget _buildRequirementCard(
      String title, String progress, double percent, String description,
      {bool isCompleted = false}) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF374151)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF111827),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Text(
              title,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progresso:',
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontSize: 14),
                    ),
                    Text(
                      progress,
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: percent,
                    minHeight: 8,
                    backgroundColor: const Color(0xFF374151),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Color(0xFF22C55E)),
                  ),
                ),
                const SizedBox(height: 12),
                if (isCompleted)
                  Row(
                    children: [
                      const Icon(Icons.check,
                          color: Color(0xFF22C55E), size: 16),
                      const SizedBox(width: 4),
                      Text(
                        description,
                        style: GoogleFonts.poppins(
                            color: const Color(0xFF22C55E), fontSize: 12),
                      ),
                    ],
                  )
                else
                  Text(
                    description,
                    style: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(0.7), fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper para card do TCC
  static Widget _buildTCCCard() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF374151)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF111827),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Text(
              'Trabalho de Conclusão de Curso',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFF374151),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          '0%',
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Não iniciado',
                      style: GoogleFonts.poppins(
                          color: Colors.white.withOpacity(0.7), fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Disponível a partir do 7º semestre.',
                  style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.7), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper para card de lista de disciplinas
  static Widget _buildSubjectListCard(String title, List<String> subjects,
      {required bool isApproved}) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFF59E0B)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF111827),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Text(
              title,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: subjects.isEmpty
                ? Center(
                    child: Text(
                      'Selecione um curso para ver as disciplinas',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                : Column(
                    children: subjects
                        .map((subject) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Icon(
                                    isApproved ? Icons.check : Icons.add,
                                    color: isApproved
                                        ? const Color(0xFF22C55E)
                                        : const Color(0xFFF59E0B),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    subject,
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
