// TODO(push): este serviço só funciona de verdade depois de:
//   1. `flutterfire configure` gerar o firebase_options.dart e o
//      android/app/google-services.json;
//   2. o plugin com.google.gms.google-services ser descomentado no gradle
//      (ver TODOs em android/settings.gradle.kts e android/app/build.gradle.kts).
// O `Firebase.initializeApp()` é feito de forma LAZY pelo próprio
// [PushService.init] na primeira chamada (após o login) — o main.dart não
// bloqueia o startup com Firebase. Enquanto a configuração não existir, todos
// os métodos são no-op seguros: qualquer falha do Firebase é capturada e
// apenas logada — o app nunca quebra por causa do push.
// Passo a passo completo em docs/PUSH_SETUP.md.

import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'supabase_service.dart';
import '../config/rotas.dart';

/// Canal Android usado pelos pushes de vaga. Precisa bater com o
/// `channel_id` enviado pela Edge Function push-dispatch e com a meta-data
/// `default_notification_channel_id` do AndroidManifest.
const String kCanalVagasId = 'vagas';
const String kCanalVagasNome = 'Vagas em turmas';
const String kCanalVagasDescricao =
    'Avisos de vagas que abriram em turmas que você segue.';

/// Converte o `data` de uma mensagem FCM na rota interna de deep link.
///
/// Lógica pura (testada em test/core/push_service_test.dart):
/// - se houver `codigo_materia`, navega para `/turmas?codigo=<código>`;
/// - senão, tenta interpretar o `deep_link` (`nofluxo://turmas?codigo=...`)
///   que a Edge Function inclui no payload;
/// - qualquer outra coisa → `null` (sem navegação).
String? rotaDeDeepLinkPush(Map<String, dynamic> data) {
  final codigo = (data['codigo_materia'] ?? '').toString().trim();
  if (codigo.isNotEmpty) {
    return rotaTurmas(codigo: codigo);
  }

  final deepLink = data['deep_link'];
  if (deepLink is String && deepLink.trim().isNotEmpty) {
    final uri = Uri.tryParse(deepLink.trim());
    if (uri != null && uri.scheme == 'nofluxo' && uri.host == 'turmas') {
      return rotaTurmas(codigo: uri.queryParameters['codigo']);
    }
  }
  return null;
}

/// O que o [PushService.init] deve fazer nesta chamada.
enum AcaoInitPush {
  /// Firebase não configurado: não faz nada (no-op seguro).
  ignorar,

  /// Primeira chamada: configura listeners/canal E registra o token.
  configurarERegistrar,

  /// Já inicializado: só re-registra o token atual (upsert barato).
  ///
  /// Importante para logout→login de outra conta no mesmo aparelho: o
  /// logout remove o token da tabela, então cada init() precisa registrar
  /// de novo para a conta atual — listeners/canal continuam os mesmos.
  apenasRegistrar,
}

/// Lógica pura (testada em test/core/push_service_test.dart) que decide a
/// ação do init: listeners são configurados uma única vez, mas o registro
/// do token no Supabase acontece em TODA chamada.
AcaoInitPush decidirAcaoInitPush({
  required bool firebaseDisponivel,
  required bool jaInicializado,
}) {
  if (!firebaseDisponivel) return AcaoInitPush.ignorar;
  return jaInicializado
      ? AcaoInitPush.apenasRegistrar
      : AcaoInitPush.configurarERegistrar;
}

/// Serviço de push notifications (FCM + notificações locais).
///
/// Responsabilidades:
/// - pedir permissão e registrar o token FCM no Supabase
///   (RPC `registrar_device_token`), re-registrando no refresh;
/// - em foreground, exibir a notificação localmente (canal "vagas");
/// - ao tocar na notificação, navegar via [onNavigate] (callback injetado
///   para o serviço não depender do router).
///
/// Todos os métodos são no-op seguros quando o Firebase não foi inicializado.
class PushService {
  PushService({this.onNavigate});

  /// Callback de navegação (ex.: `(rota) => router.go(rota)`), injetado por
  /// quem inicializa o serviço para não acoplar o push ao go_router.
  void Function(String rota)? onNavigate;

  final FlutterLocalNotificationsPlugin _notificacoesLocais =
      FlutterLocalNotificationsPlugin();

  bool _inicializado = false;

  /// Token FCM atual (null se ainda não obtido). Guardado para o
  /// [unregister] conseguir remover o registro no logout.
  String? _tokenAtual;

  bool get _firebaseDisponivel {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (erro) {
      _log('Firebase indisponível', erro);
      return false;
    }
  }

  /// Tenta o `Firebase.initializeApp()` de forma lazy e idempotente.
  ///
  /// Sem os arquivos de configuração por plataforma (google-services.json /
  /// GoogleService-Info.plist), o initializeApp lança — a falha é capturada e
  /// apenas logada, e o push fica desabilitado (no-op seguro).
  Future<void> _garantirFirebaseInicializado() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
    } catch (erro) {
      _log('Firebase não inicializado (push desabilitado)', erro);
    }
  }

  /// Inicializa o pipeline de push. Chamar com sessão Supabase ativa (o
  /// registro do token exige usuário logado); o `Firebase.initializeApp()` é
  /// tentado aqui mesmo, de forma lazy, na primeira chamada.
  ///
  /// Idempotente para listeners/canal (configurados uma única vez), mas o
  /// token é re-registrado no Supabase em TODA chamada — necessário para
  /// logout→login de outra conta no mesmo aparelho, já que o logout remove
  /// o registro do token via `remover_device_token`.
  Future<void> init({void Function(String rota)? onNavigate}) async {
    if (onNavigate != null) this.onNavigate = onNavigate;

    await _garantirFirebaseInicializado();

    final acao = decidirAcaoInitPush(
      firebaseDisponivel: _firebaseDisponivel,
      jaInicializado: _inicializado,
    );

    switch (acao) {
      case AcaoInitPush.ignorar:
        _log(
          'init ignorado: Firebase não configurado nesta plataforma '
          '(ver TODO no topo de push_service.dart)',
        );
        return;
      case AcaoInitPush.apenasRegistrar:
        await registerCurrentToken();
        return;
      case AcaoInitPush.configurarERegistrar:
        break;
    }

    try {
      final mensageria = FirebaseMessaging.instance;

      // 1. Permissão (Android 13+ exige POST_NOTIFICATIONS; iOS sempre).
      final permissao = await mensageria.requestPermission();
      if (permissao.authorizationStatus == AuthorizationStatus.denied) {
        _log('Permissão de notificação negada pelo usuário');
        // Continua mesmo assim: o token ainda é registrado; se o usuário
        // autorizar depois nas configurações, o push volta a funcionar.
      }

      // 2. Notificações locais (para exibir push recebido em foreground).
      await _inicializarNotificacoesLocais();

      // 3. Token: obtém e registra no Supabase.
      await registerCurrentToken();

      // 4. Refresh de token → re-registra.
      mensageria.onTokenRefresh.listen(
        _registrarToken,
        onError: (Object erro) => _log('onTokenRefresh falhou', erro),
      );

      // 5. Mensagem com o app em foreground → notificação local.
      FirebaseMessaging.onMessage.listen(
        _aoReceberEmForeground,
        onError: (Object erro) => _log('onMessage falhou', erro),
      );

      // 6. Toque na notificação com o app em background → deep link.
      FirebaseMessaging.onMessageOpenedApp.listen(
        _aoAbrirPelaNotificacao,
        onError: (Object erro) => _log('onMessageOpenedApp falhou', erro),
      );

      // 7. App aberto a partir de estado terminado por uma notificação.
      final mensagemInicial = await mensageria.getInitialMessage();
      if (mensagemInicial != null) {
        _aoAbrirPelaNotificacao(mensagemInicial);
      }

      _inicializado = true;
    } catch (erro, stack) {
      _log('init do push falhou (no-op seguro)', erro, stack);
    }
  }

  /// Obtém o token FCM atual e o registra no Supabase para a conta logada.
  ///
  /// Seguro chamar a qualquer momento (ex.: no listener de login do app,
  /// via onAuthStateChange): é o mesmo upsert barato usado pelo init().
  Future<void> registerCurrentToken() async {
    if (!_firebaseDisponivel) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _registrarToken(token);
      }
    } catch (erro, stack) {
      _log('registerCurrentToken falhou (no-op seguro)', erro, stack);
    }
  }

  /// Remove o token deste aparelho do Supabase (RPC `remover_device_token`).
  /// Chamar no logout, ANTES de encerrar a sessão Supabase (a RPC usa o
  /// auth.uid() da sessão para autorizar a remoção).
  Future<void> unregister() async {
    try {
      final token =
          _tokenAtual ??
          (_firebaseDisponivel
              ? await FirebaseMessaging.instance.getToken()
              : null);
      if (token == null) return;

      await SupabaseService.client.rpc(
        'remover_device_token',
        params: {'p_token': token},
      );
      _tokenAtual = null;
      _log('Token de push removido do Supabase');
    } catch (erro, stack) {
      _log('unregister do push falhou (no-op seguro)', erro, stack);
    }
  }

  // -------------------------------------------------------------------------
  // Internos
  // -------------------------------------------------------------------------

  Future<void> _inicializarNotificacoesLocais() async {
    const configuracao = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _notificacoesLocais.initialize(
      settings: configuracao,
      // Toque em notificação local (exibida em foreground): o payload é a
      // rota de deep link já resolvida.
      onDidReceiveNotificationResponse: (resposta) {
        final rota = resposta.payload;
        if (rota != null && rota.isNotEmpty) {
          _navegar(rota);
        }
      },
    );

    // Cria o canal "vagas" no Android (idempotente).
    const canal = AndroidNotificationChannel(
      kCanalVagasId,
      kCanalVagasNome,
      description: kCanalVagasDescricao,
      importance: Importance.high,
    );
    await _notificacoesLocais
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(canal);
  }

  Future<void> _registrarToken(String token) async {
    try {
      _tokenAtual = token;
      if (SupabaseService.session == null) {
        _log('Token FCM obtido, mas sem sessão Supabase — registro adiado');
        return;
      }
      await SupabaseService.client.rpc(
        'registrar_device_token',
        params: {'p_token': token, 'p_platform': _plataforma()},
      );
      _log('Token de push registrado no Supabase');
    } catch (erro, stack) {
      _log('Registro do token de push falhou (no-op seguro)', erro, stack);
    }
  }

  /// Push recebido com o app aberto: o Android não mostra a notificação do
  /// FCM em foreground, então exibimos uma notificação local no canal "vagas".
  Future<void> _aoReceberEmForeground(RemoteMessage mensagem) async {
    try {
      final notificacao = mensagem.notification;
      final titulo = notificacao?.title ?? 'NoFluxoUNB';
      final corpo = notificacao?.body ?? '';
      final rota = rotaDeDeepLinkPush(mensagem.data);

      const detalhes = NotificationDetails(
        android: AndroidNotificationDetails(
          kCanalVagasId,
          kCanalVagasNome,
          channelDescription: kCanalVagasDescricao,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );

      await _notificacoesLocais.show(
        // Id derivado do hash para não empilhar duplicatas da mesma notificação.
        id:
            mensagem.messageId?.hashCode ??
            DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
        title: titulo,
        body: corpo,
        notificationDetails: detalhes,
        payload: rota,
      );
    } catch (erro, stack) {
      _log('Exibição de notificação em foreground falhou', erro, stack);
    }
  }

  /// Toque na notificação (app em background/terminado): resolve o deep link.
  void _aoAbrirPelaNotificacao(RemoteMessage mensagem) {
    final rota = rotaDeDeepLinkPush(mensagem.data);
    if (rota != null) {
      _navegar(rota);
    }
  }

  void _navegar(String rota) {
    final callback = onNavigate;
    if (callback == null) {
      _log('Deep link "$rota" ignorado: onNavigate não foi injetado');
      return;
    }
    try {
      callback(rota);
    } catch (erro, stack) {
      _log('Navegação do deep link "$rota" falhou', erro, stack);
    }
  }

  String _plataforma() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
      default:
        return 'android';
    }
  }

  void _log(String mensagem, [Object? erro, StackTrace? stack]) {
    developer.log(
      mensagem,
      name: 'PushService',
      error: erro,
      stackTrace: stack,
    );
  }
}

/// Provider do serviço de push.
///
/// Uso previsto (quando o Firebase estiver configurado — ver docs/PUSH_SETUP.md):
/// ```dart
/// final push = ref.read(pushServiceProvider);
/// await push.init(onNavigate: (rota) => router.go(rota));
/// // no logout, antes do signOut:
/// await push.unregister();
/// ```
final pushServiceProvider = Provider<PushService>((ref) => PushService());
