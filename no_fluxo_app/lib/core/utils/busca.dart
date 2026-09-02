/// Sanitização de termo de busca para o PostgREST — fonte única.
///
/// Usada por toda busca de matérias (features Turmas e Grade); sem Flutter,
/// sem Supabase.
library;

/// Tamanho mínimo do termo de busca (mesma regra do site).
const int kMinCaracteresBusca = 2;

/// Sanitiza o termo digitado antes de ir para o PostgREST.
///
/// Vírgula e parênteses delimitam filtros no PostgREST e `%` é curinga do
/// `ilike` — todos viram espaço. Espaços repetidos são colapsados.
String sanitizarTermoBusca(String termo) {
  return termo
      .replaceAll(RegExp(r'[%,()]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
