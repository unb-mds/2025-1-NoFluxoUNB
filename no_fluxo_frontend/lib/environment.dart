import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logging/logging.dart';
import 'package:stack_trace/stack_trace.dart';

import 'cache/shared_preferences_helper.dart';

enum EnvironmentType {
  development,
  production,
}

class Environment {
  static String apiUrl = "http://localhost:3000";
  static String redirectToUrl = "http://localhost:5000";

  static EnvironmentType environmentType = EnvironmentType.development;
  static bool _initialized = false;

  static bool _loggingInitialized = false;
  static StreamSubscription<LogRecord>? _logSubscription;

  /// Initialize environment configuration. This should be called once at app startup.
  static void initialize() {
    if (_initialized) return;

    // Check for NO_FLUXO_PROD environment variable
    bool isProd = false;

    if (!kIsWeb) {
      // On native platforms, check environment variables
      isProd = Platform.environment.containsKey('NO_FLUXO_PROD');
    } else {
      // On web, check compile-time constant (set via --dart-define)
      isProd = const bool.fromEnvironment('NO_FLUXO_PROD', defaultValue: false);
    }

    final logger = getLogger('Environment');
    logger
        .info('🌍 Initializing environment - isProd: $isProd, isWeb: $kIsWeb');

    logger.info('🔗 API URL: $apiUrl');
    logger.info('🔄 Redirect URL: $redirectToUrl');

    if (isProd) {
      setEnvironmentType(EnvironmentType.production);
      logger.info('🏭 Production environment configured');
    } else {
      setEnvironmentType(EnvironmentType.development);
      logger.info('🧪 Development environment configured');
    }

    _initialized = true;

    logger.info('🔗 API URL: $apiUrl');
    logger.info('🔄 Redirect URL: $redirectToUrl');
  }

  /// Initialize logging configuration. This should be called once at app startup.
  static void initializeLogging() {
    if (_loggingInitialized) return;

    // Cancel any existing subscription
    _logSubscription?.cancel();

    // Remove any existing handlers
    Logger.root.clearListeners();

    Logger.root.level = Level.ALL;

    // Create a new subscription
    _logSubscription = Logger.root.onRecord.listen((record) {
      final time = _formatDateTime(record.time.toUtc());
      final level = record.level.name;
      final loggerName = record.loggerName;
      var message = record.message;

      // Clean up any extra brackets in the message
      if (message.startsWith("[") && !message.startsWith("[\b")) {
        message = "\b$message";
      }

      // Only add brackets to logger name if it's not empty
      final formattedLoggerName = loggerName.isEmpty ? '' : "[$loggerName]";
      String logMessage = '[$level][$time]$formattedLoggerName $message';

      // Print to console
      print(logMessage);

      // If there's an error and stack trace, print them
      if (record.error != null) {
        print('Error: ${record.error}');
        if (record.stackTrace != null) {
          // Format the stack trace
          final chain = Chain.forTrace(record.stackTrace!);
          final trace = chain.terse;
          print('Stack trace:\n$trace');
        }
      }
    });

    hierarchicalLoggingEnabled = true;
    _loggingInitialized = true;
  }

  /// Get a logger instance with the specified name.
  /// The name should be in the format 'component_name' without brackets.
  static Logger getLogger(String name) {
    if (!_loggingInitialized) {
      initializeLogging();
    }
    // Remove any extra brackets to prevent double bracketing
    final cleanName = name.replaceAll(RegExp(r'^\[+|\]+$'), '');
    return Logger(cleanName);
  }

  /// Format DateTime for logging
  static String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }

  static String getApiUrl() {
    if (!_initialized) {
      initialize();
    }
    return apiUrl;
  }

  static String getRedirectToUrl() {
    if (!_initialized) {
      initialize();
    }
    return redirectToUrl;
  }

  static void setEnvironmentType(EnvironmentType environmentType) {
    Environment.environmentType = environmentType;

    if (environmentType == EnvironmentType.development) {
      apiUrl = "http://localhost:3000";
      redirectToUrl = "http://localhost:5000";
    } else {
      apiUrl = "https://srv892492.hstgr.cloud:3000";
      redirectToUrl = "https://no-fluxo.com";
    }
  }

  static Future<Map<String, String>> getHeadersForAuthorizedRequest() async {
    final session = await Supabase.instance.client.auth.refreshSession();
    return {
      "Authorization": session.session?.accessToken ?? "",
      "User-ID": SharedPreferencesHelper.currentUser?.idUser.toString() ?? "",
      "Content-Type": "application/json"
    };
  }

  /// Clean up logging resources when the app is disposed
  static void dispose() {
    _logSubscription?.cancel();
    Logger.root.clearListeners();
    _loggingInitialized = false;
  }
}
