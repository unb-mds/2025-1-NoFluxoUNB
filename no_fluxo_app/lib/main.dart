import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import 'app/router.dart';
import 'core/config/app_config.dart';
import 'core/dev/dev_log.dart';
import 'core/services/auth_service.dart';
import 'core/services/push_service.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Console de erros do modo dev: captura debugPrint + FlutterError para o
  // painel dentro do app (não existe em release).
  if (kDebugMode) DevLog.instalar();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    // A chave anon legada (JWT) é aceita como publishable key.
    publishableKey: AppConfig.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  // O Firebase NÃO é inicializado aqui: o PushService.init() faz o
  // Firebase.initializeApp() de forma lazy na primeira chamada (após o
  // login), sem bloquear o startup — ver push_service.dart.

  // Banco de timezones para agendar notificações locais em horário de
  // Brasília independentemente do fuso do aparelho.
  tz.initializeTimeZones();

  runApp(const ProviderScope(child: NoFluxoApp()));
}

class NoFluxoApp extends ConsumerWidget {
  const NoFluxoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // Registra o aparelho para push quando o aluno loga (no-op seguro
    // enquanto o Firebase não estiver configurado — ver docs/PUSH_SETUP.md).
    ref.listen(authProvider, (anterior, atual) {
      final logouAgora =
          atual.valueOrNull?.status == AuthStatus.loggedIn &&
          anterior?.valueOrNull?.status != AuthStatus.loggedIn;
      if (logouAgora) {
        ref
            .read(pushServiceProvider)
            .init(onNavigate: (rota) => router.go(rota));
      }
    });

    return MaterialApp.router(
      title: 'NoFluxo UnB',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      routerConfig: router,
    );
  }
}
