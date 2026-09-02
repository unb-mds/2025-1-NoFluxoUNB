/// Fakes compartilhados dos testes de suporte.
library;

import 'package:no_fluxo_app/features/suporte/data/suporte_repository.dart';
import 'package:no_fluxo_app/features/suporte/data/ticket_model.dart';

/// Registro de uma chamada a `criarTicket`.
class ChamadaCriarTicket {
  final String title;
  final String description;
  final TicketCategoria categoria;

  const ChamadaCriarTicket({
    required this.title,
    required this.description,
    required this.categoria,
  });
}

/// Repositório fake em memória com registro de chamadas.
class FakeSuporteRepository implements SuporteRepository {
  List<TicketModel> tickets;

  /// Erros a lançar (para testar estados de falha).
  Object? erroAoListar;
  Object? erroAoCriar;

  final List<ChamadaCriarTicket> chamadasCriar = [];
  int chamadasListar = 0;

  FakeSuporteRepository({this.tickets = const []});

  @override
  Future<TicketModel> criarTicket({
    required String title,
    required String description,
    required TicketCategoria categoria,
  }) async {
    chamadasCriar.add(
      ChamadaCriarTicket(
        title: title,
        description: description,
        categoria: categoria,
      ),
    );
    final erro = erroAoCriar;
    if (erro != null) throw erro;
    final criado = TicketModel(
      id: tickets.length + 1,
      createdBy: 'auth-uid-teste',
      title: title.trim(),
      description: description.trim(),
      category: categoria.valor,
      status: 'aberto',
      createdAt: DateTime.now(),
    );
    tickets = [criado, ...tickets];
    return criado;
  }

  @override
  Future<List<TicketModel>> meusTickets() async {
    chamadasListar++;
    final erro = erroAoListar;
    if (erro != null) throw erro;
    return List<TicketModel>.from(tickets);
  }
}

/// Atalho para montar um ticket nos testes.
TicketModel ticketDeTeste({
  int id = 1,
  String title = 'Bug no fluxograma',
  String status = 'aberto',
  String category = 'bug',
  DateTime? createdAt,
}) {
  return TicketModel(
    id: id,
    createdBy: 'auth-uid-teste',
    title: title,
    description: 'descrição',
    category: category,
    status: status,
    createdAt: createdAt ?? DateTime.now().subtract(const Duration(hours: 2)),
  );
}
