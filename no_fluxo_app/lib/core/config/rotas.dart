/// Contrato das rotas do app que são construídas fora da própria feature
/// (deep links de push, inbox e fluxograma). Mudou a rota? Muda aqui — os
/// construtores e o parse apontam todos para este arquivo.
library;

/// Location da aba Turmas, opcionalmente com a busca pré-preenchida
/// (`/turmas?codigo=CIC0004`). O parse correspondente vive em
/// `features/turmas/routes.dart` (query param `codigo`).
String rotaTurmas({String? codigo}) {
  final c = codigo?.trim() ?? '';
  if (c.isEmpty) return '/turmas';
  return Uri(path: '/turmas', queryParameters: {'codigo': c}).toString();
}
