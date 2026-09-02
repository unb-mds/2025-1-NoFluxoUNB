/// Decisão do redirect pós-login para o onboarding de importação — análogo
/// ao `post-login-redirect.ts` do site, adaptado ao go_router (função pura,
/// chamada pelo redirect global em lib/app/router.dart).
library;

import '../../../core/services/auth_service.dart';

/// Rota da tela de importação (fora do shell de abas).
const String kRotaImportarHistorico = '/importar-historico';

/// Retorna o destino do redirect de onboarding, ou null para não redirecionar.
///
/// Regras:
/// - visitante NUNCA é levado ao onboarding (e sai da tela se cair nela);
/// - logado com perfil carregado e SEM fluxograma → [kRotaImportarHistorico],
///   exceto se já está lá ou se adiou nesta sessão ("Agora não");
/// - perfil ainda não carregado (boot offline) não redireciona — o dado pode
///   existir e só não ter chegado.
String? redirectImportacaoDeHistorico({
  required AuthStatus status,
  required bool perfilCarregado,
  required bool temFluxograma,
  required bool adiou,
  required String location,
}) {
  final naTelaDeImportacao = location == kRotaImportarHistorico;

  if (status == AuthStatus.anonymous) {
    return naTelaDeImportacao ? '/fluxograma' : null;
  }
  if (status != AuthStatus.loggedIn) return null;

  if (perfilCarregado && !temFluxograma && !adiou && !naTelaDeImportacao) {
    return kRotaImportarHistorico;
  }
  return null;
}
