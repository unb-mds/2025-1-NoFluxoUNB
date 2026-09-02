/// Configuração de ambiente do app.
///
/// Todos os valores podem ser sobrescritos em build/run com `--dart-define`:
/// ```
/// flutter run --dart-define=API_URL=http://localhost:3333
/// ```
/// Os defaults apontam para produção. A anon key do Supabase é pública por
/// definição (RLS protege os dados), então é seguro mantê-la hardcoded.
class AppConfig {
  AppConfig._();

  /// URL do projeto Supabase.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://lijmhbstgdinsukovyfl.supabase.co',
  );

  /// Chave anônima (pública) do Supabase.
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxpam1oYnN0Z2RpbnN1a292eWZsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc4MzkzNzMsImV4cCI6MjA2MzQxNTM3M30.A0bqhbEOn1SdDa5s6d9xFKHXgwpDZOA-1QJpfftFoco',
  );

  /// URL base da API Express (backend do assistente/planejamento).
  ///
  /// O domínio de produção é `api-nofluxo.crianex.com` — o mesmo que o site
  /// usa. Atenção: `no-fluxo.com` aparece em docs antigas do repo mas NÃO
  /// existe (o DNS não resolve); o frontend em produção é
  /// `no-fluxo.crianex.com`.
  ///
  /// Em dev local use `--dart-define=API_URL=http://localhost:3333`
  /// (no emulador Android, `http://10.0.2.2:3333`).
  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://api-nofluxo.crianex.com',
  );

  /// Site (frontend Svelte) em produção — usado nos links que mandam o aluno
  /// para funcionalidades que ainda não existem no app.
  static const String siteUrl = String.fromEnvironment(
    'SITE_URL',
    defaultValue: 'https://no-fluxo.crianex.com',
  );

  /// Host do site sem esquema, para exibir em textos ("use o site X").
  static String get siteHost => Uri.parse(siteUrl).host;

  /// Contas de teste do modo dev (painel na tela de login, só em debug).
  ///
  /// As credenciais NÃO vivem no código (repo público): ficam no
  /// `dev.env.json` gitignorado, carregado com
  /// `flutter run --dart-define-from-file=dev.env.json`.
  /// Sem elas o painel ainda funciona com e-mail/senha digitados (lembrados).
  static const String devAlunoEmail = String.fromEnvironment('DEV_ALUNO_EMAIL');
  static const String devAlunoSenha = String.fromEnvironment('DEV_ALUNO_SENHA');
  static const String devAdminEmail = String.fromEnvironment('DEV_ADMIN_EMAIL');
  static const String devAdminSenha = String.fromEnvironment('DEV_ADMIN_SENHA');
}
