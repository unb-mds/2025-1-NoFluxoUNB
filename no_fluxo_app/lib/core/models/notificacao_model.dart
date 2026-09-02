import '../utils/json_utils.dart';

/// Notificação do usuário (shape da RPC `listar_notificacoes`).
class NotificacaoModel {
  final int idNotificacao;
  final DateTime? createdAt;

  /// Tipo da notificação (ex.: "vaga_aberta").
  final String tipo;
  final String titulo;
  final String mensagem;

  /// Payload extra específico do tipo (ex.: código da matéria, turma).
  final Map<String, dynamic> metadata;
  final bool lida;
  final DateTime? lidaEm;

  const NotificacaoModel({
    required this.idNotificacao,
    this.createdAt,
    required this.tipo,
    required this.titulo,
    required this.mensagem,
    this.metadata = const {},
    this.lida = false,
    this.lidaEm,
  });

  factory NotificacaoModel.fromJson(Map<String, dynamic> json) {
    return NotificacaoModel(
      idNotificacao: parseIntOr(json['id_notificacao']),
      createdAt: parseDateTimeOrNull(json['created_at']),
      tipo: parseStringOr(json['tipo']),
      titulo: parseStringOr(json['titulo']),
      mensagem: parseStringOr(json['mensagem']),
      metadata: asMapOrNull(json['metadata']) ?? const {},
      lida: parseBoolOr(json['lida']),
      lidaEm: parseDateTimeOrNull(json['lida_em']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_notificacao': idNotificacao,
      'created_at': createdAt?.toIso8601String(),
      'tipo': tipo,
      'titulo': titulo,
      'mensagem': mensagem,
      'metadata': metadata,
      'lida': lida,
      'lida_em': lidaEm?.toIso8601String(),
    };
  }

  NotificacaoModel copyWith({bool? lida, DateTime? lidaEm}) {
    return NotificacaoModel(
      idNotificacao: idNotificacao,
      createdAt: createdAt,
      tipo: tipo,
      titulo: titulo,
      mensagem: mensagem,
      metadata: metadata,
      lida: lida ?? this.lida,
      lidaEm: lidaEm ?? this.lidaEm,
    );
  }
}
