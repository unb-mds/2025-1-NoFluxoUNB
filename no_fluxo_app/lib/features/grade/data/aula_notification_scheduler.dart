/// Camada fina sobre `flutter_local_notifications` para os avisos de
/// "aula começando".
///
/// Toda a matemática dos disparos vive em `domain/grade_builder.dart`
/// ([calcularAgendamentos]) — aqui só se traduz o resultado em chamadas de
/// plugin, com recorrência semanal
/// ([DateTimeComponents.dayOfWeekAndTime]) e regravação via `cancelAll`.
///
/// Erros de plataforma (plugin ausente nos testes, permissão negada etc.)
/// são engolidos com log: notificação é conveniência, nunca pode derrubar a
/// tela da grade.
///
/// Preferências em `shared_preferences`:
/// - `grade_notif_ativas` (bool, default false): toggle "Avisar antes da aula";
/// - `grade_notif_antecedencia_min` (int, default 30): minutos de antecedência.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../domain/grade_builder.dart';

/// Configuração dos avisos de aula, persistida localmente.
class ConfigNotificacaoAulas {
  /// Toggle "Avisar antes da aula".
  final bool ativas;

  /// Antecedência do aviso, em minutos (10/30/60 na UI).
  final int antecedenciaMin;

  const ConfigNotificacaoAulas({
    this.ativas = false,
    this.antecedenciaMin = 30,
  });

  ConfigNotificacaoAulas copyWith({bool? ativas, int? antecedenciaMin}) =>
      ConfigNotificacaoAulas(
        ativas: ativas ?? this.ativas,
        antecedenciaMin: antecedenciaMin ?? this.antecedenciaMin,
      );
}

/// Agenda (e regrava) as notificações locais de aula da grade.
class AulaNotificationScheduler {
  static const _kAtivasKey = 'grade_notif_ativas';
  static const _kAntecedenciaKey = 'grade_notif_antecedencia_min';

  static const _canalId = 'aulas';
  static const _canalNome = 'Aulas';
  static const _canalDescricao = 'Avisos de aula começando';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _inicializado = false;

  AulaNotificationScheduler([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  // ── Configuração persistida ────────────────────────────────────────────────

  Future<ConfigNotificacaoAulas> carregarConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return ConfigNotificacaoAulas(
      ativas: prefs.getBool(_kAtivasKey) ?? false,
      antecedenciaMin: prefs.getInt(_kAntecedenciaKey) ?? 30,
    );
  }

  Future<void> salvarConfig(ConfigNotificacaoAulas config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAtivasKey, config.ativas);
    await prefs.setInt(_kAntecedenciaKey, config.antecedenciaMin);
  }

  // ── Plugin ─────────────────────────────────────────────────────────────────

  /// Fuso das aulas: os horários da UnB são sempre de Brasília. Cai para
  /// `tz.local` se o banco de fusos não tiver a entrada (não deve acontecer —
  /// `tz.initializeTimeZones()` roda no main).
  tz.Location get _fusoAulas {
    try {
      return tz.getLocation('America/Sao_Paulo');
    } catch (_) {
      return tz.local;
    }
  }

  /// Inicializa o plugin, cria o canal Android "aulas" e pede permissão de
  /// notificação. Retorna false se a plataforma não suportar (ex.: testes).
  Future<bool> init() async {
    if (_inicializado) return true;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );

      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _canalId,
          _canalNome,
          description: _canalDescricao,
          importance: Importance.high,
        ),
      );
      await android?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);

      _inicializado = true;
      return true;
    } on MissingPluginException catch (e) {
      debugPrint('Notificações de aula indisponíveis (sem plugin): $e');
      return false;
    } catch (e) {
      debugPrint('Falha ao inicializar notificações de aula: $e');
      return false;
    }
  }

  /// Regrava os agendamentos para a grade atual: cancela tudo e, se o toggle
  /// estiver ligado, agenda um aviso semanal recorrente por bloco de aula.
  ///
  /// [now] é injetável para teste; default `DateTime.now()`.
  Future<void> sincronizar(List<TurmaGrade> turmas, {DateTime? now}) async {
    try {
      final config = await carregarConfig();

      if (!config.ativas) {
        // Toggle desligado: só garante que nada fica agendado.
        await _cancelarTudoSilencioso();
        return;
      }
      if (!await init()) return;

      await _plugin.cancelAll();

      final agendamentos = calcularAgendamentos(
        turmas: turmas,
        now: now ?? DateTime.now(),
        antecedencia: Duration(minutes: config.antecedenciaMin),
      );

      final fuso = _fusoAulas;
      for (final a in agendamentos) {
        // Reconstrói o horário de parede no fuso de Brasília — os horários
        // dos blocos são horários de Brasília por definição.
        final quando = tz.TZDateTime(
          fuso,
          a.dateTime.year,
          a.dateTime.month,
          a.dateTime.day,
          a.dateTime.hour,
          a.dateTime.minute,
        );

        await _plugin.zonedSchedule(
          id: a.id,
          title: a.titulo,
          body: a.corpo,
          scheduledDate: quando,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              _canalId,
              _canalNome,
              channelDescription: _canalDescricao,
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          // Sem permissão de alarme exato; para aviso de aula, inexato basta.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          // Recorrência semanal: mesmo dia da semana + horário.
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
    } on MissingPluginException catch (e) {
      debugPrint('Notificações de aula indisponíveis (sem plugin): $e');
    } catch (e) {
      debugPrint('Falha ao agendar notificações de aula: $e');
    }
  }

  Future<void> _cancelarTudoSilencioso() async {
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('Falha ao cancelar notificações de aula: $e');
    }
  }
}

/// Agendador de notificações de aula (override em testes com um fake).
final aulaNotificationSchedulerProvider = Provider<AulaNotificationScheduler>(
  (ref) => AulaNotificationScheduler(),
);
