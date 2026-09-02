import '../../../core/utils/json_utils.dart';

/// Categoria de um chamado de suporte — mesmos valores do site
/// (`TicketCategory` em src/lib/types/ticket.ts).
enum TicketCategoria {
  bug('bug', 'Bug'),
  sugestao('sugestao', 'Sugestão'),
  duvida('duvida', 'Dúvida');

  /// Valor persistido na coluna `tickets.category`.
  final String valor;

  /// Rótulo exibido na UI.
  final String label;

  const TicketCategoria(this.valor, this.label);

  static TicketCategoria? fromValor(String? valor) {
    for (final c in TicketCategoria.values) {
      if (c.valor == valor) return c;
    }
    return null;
  }
}

/// Uma linha da tabela `tickets` (Supabase) — parsing defensivo: campo
/// ausente, nulo ou com tipo errado nunca estoura.
class TicketModel {
  final int id;
  final String createdBy;
  final String title;
  final String description;

  /// 'bug' | 'sugestao' | 'duvida' (cru, como veio do banco).
  final String category;

  /// 'aberto' | 'em_andamento' | 'aguardando_info' | 'resolvido' | 'fechado'.
  final String status;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;

  const TicketModel({
    this.id = 0,
    this.createdBy = '',
    this.title = '',
    this.description = '',
    this.category = '',
    this.status = 'aberto',
    this.metadata = const {},
    this.createdAt,
  });

  factory TicketModel.fromJson(Map<String, dynamic> json) {
    return TicketModel(
      id: parseIntOr(json['id']),
      createdBy: parseStringOr(json['created_by']),
      title: parseStringOr(json['title']),
      description: parseStringOr(json['description']),
      category: parseStringOr(json['category']),
      status: parseStringOr(json['status'], 'aberto'),
      metadata: asMapOrNull(json['metadata']) ?? const {},
      createdAt: DateTime.tryParse(parseStringOr(json['created_at'])),
    );
  }

  TicketCategoria? get categoria => TicketCategoria.fromValor(category);

  /// Rótulo humano do status ('em_andamento' → 'Em andamento').
  String get statusLabel {
    switch (status) {
      case 'aberto':
        return 'Aberto';
      case 'em_andamento':
        return 'Em andamento';
      case 'aguardando_info':
        return 'Aguardando info';
      case 'resolvido':
        return 'Resolvido';
      case 'fechado':
        return 'Fechado';
      default:
        return status.isEmpty ? '—' : status;
    }
  }
}
