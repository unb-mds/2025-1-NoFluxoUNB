/// Versão do "pacote de novidades" do app e do schema do fluxograma salvo.
///
/// ATENÇÃO: este arquivo é o espelho de
/// `no_fluxo_frontend_svelte/src/lib/config/release.ts` e DEVE acompanhar as
/// mudanças de lá — em especial [kFluxogramaSchemaVersion], que decide quando
/// o app pede reenvio do histórico.
///
/// Como usar num release novo do app:
/// 1. Mude [kReleaseId] (qualquer string nova reabre o dialog de novidades
///    uma vez por usuário).
/// 2. Atualize [kNovidades] com o que mudou, na voz do usuário.
/// 3. Incremente [kFluxogramaSchemaVersion] SOMENTE se o dado salvo pelo
///    upload ganhou informação nova (aí o card do Perfil pede reenvio do
///    histórico para quem tem dado de versão anterior) — sempre em sincronia
///    com `FLUXOGRAMA_SCHEMA_VERSION` do site.
library;

/// Identificador deste release — mudar reabre o dialog de novidades.
const String kReleaseId = '2026-09-app-v1';

/// Título do dialog de novidades.
const String kNovidadesTitulo = 'Novidades no NoFluxo';

/// O que há de novo neste release, na voz do usuário.
const List<String> kNovidades = [
  'O NoFluxo agora tem app! Fluxograma, progresso e perfil na palma da mão',
  'Alertas de vaga: ative o sino numa turma e receba aviso quando abrir vaga',
  'Grade horária da semana com lembretes das suas aulas',
  'Assistente IA para tirar dúvidas sobre seu curso e planejar matérias',
];

/// Versão do schema do `fluxograma_atual` salvo no upload de histórico.
///
/// Espelho de `FLUXOGRAMA_SCHEMA_VERSION` do site (src/lib/config/release.ts):
/// - v1: uploads antigos (sem o campo `schema_version`);
/// - v2: equivalências do próprio histórico injetadas + módulo livre/extras.
const int kFluxogramaSchemaVersion = 2;
