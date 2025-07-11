import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/materia_model.dart';

class OptativasModal extends StatefulWidget {
  final List<MateriaModel> optativasDisponiveis;
  final Function(MateriaModel, int) onOptativaSelecionada;
  final VoidCallback onCancelOptativa;

  const OptativasModal({
    Key? key,
    required this.optativasDisponiveis,
    required this.onOptativaSelecionada,
    required this.onCancelOptativa,
  }) : super(key: key);

  @override
  State<OptativasModal> createState() => _OptativasModalState();
}

class _OptativasModalState extends State<OptativasModal> {
  String searchQuery = '';
  MateriaModel? selectedMateria;
  int selectedSemestre = 1;

  List<MateriaModel> get filteredMaterias {
    if (searchQuery.isEmpty) {
      return widget.optativasDisponiveis;
    }
    return widget.optativasDisponiveis
        .where((materia) =>
            materia.nomeMateria
                .toLowerCase()
                .contains(searchQuery.toLowerCase()) ||
            materia.codigoMateria
                .toLowerCase()
                .contains(searchQuery.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade600, Colors.blue.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Adicionar Optativa',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      onPressed: widget.onCancelOptativa,
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),

              // Search and semester selector
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Search field
                    TextField(
                      onChanged: (value) {
                        setState(() {
                          searchQuery = value;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Buscar optativa',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Semester selector
                    Row(
                      children: [
                        Text(
                          'Semestre: ',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        DropdownButton<int>(
                          value: selectedSemestre,
                          items: List.generate(10, (index) => index + 1)
                              .map((semestre) => DropdownMenuItem(
                                    value: semestre,
                                    child: Text('${semestre}º'),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedSemestre = value!;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Table header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade300),
                    bottom: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                        width: 100,
                        child: Text('Código',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    const SizedBox(
                        width: 300,
                        child: Text('Nome',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    const SizedBox(
                        width: 80,
                        child: Text('Créditos',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    const SizedBox(
                        width: 100,
                        child: Text('Semestre',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    const Text('Ação',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),

              // Table content
              Expanded(
                child: ListView.builder(
                  itemCount: filteredMaterias.length,
                  itemBuilder: (context, index) {
                    final materia = filteredMaterias[index];
                    final isSelected =
                        selectedMateria?.codigoMateria == materia.codigoMateria;

                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blue.shade50 : null,
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 100,
                            child: Text(
                              materia.codigoMateria,
                              style: GoogleFonts.poppins(fontSize: 14),
                            ),
                          ),
                          SizedBox(
                            width: 300,
                            child: Text(
                              materia.nomeMateria,
                              style: GoogleFonts.poppins(fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: Text(
                              materia.creditos.toString(),
                              style: GoogleFonts.poppins(fontSize: 14),
                            ),
                          ),
                          SizedBox(
                            width: 100,
                            child: Text(
                              '${selectedSemestre}º',
                              style: GoogleFonts.poppins(fontSize: 14),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                selectedMateria = isSelected ? null : materia;
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isSelected
                                  ? Colors.red.shade600
                                  : Colors.green.shade600,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                            ),
                            child: Text(
                              isSelected ? 'Selecionada' : 'Selecionar',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Selected optativa summary
              if (selectedMateria != null)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Optativa Selecionada:',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${selectedMateria!.codigoMateria} - ${selectedMateria!.nomeMateria}',
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                      Text(
                        'Créditos: ${selectedMateria!.creditos} | Semestre: ${selectedSemestre}º',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

              // Action buttons
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: widget.onCancelOptativa,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade600,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                      child: Text(
                        'CANCELAR',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: selectedMateria != null
                          ? () {
                              widget.onOptativaSelecionada(
                                  selectedMateria!, selectedSemestre);
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedMateria != null
                            ? Colors.green.shade600
                            : Colors.grey.shade400,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                      child: Text(
                        'CONFIRMAR',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
