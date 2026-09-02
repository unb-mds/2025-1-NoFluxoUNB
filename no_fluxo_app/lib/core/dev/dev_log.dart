import 'package:flutter/foundation.dart';

/// Console de erros/logs do modo dev (só builds de debug).
///
/// Captura tudo que passa por [debugPrint] (os services do app logam por
/// ele) e os erros de framework ([FlutterError.onError]), num ring buffer
/// que o painel dev exibe dentro do próprio app — dá para investigar falhas
/// no simulador/aparelho sem cabo nem Xcode.
class DevLog {
  DevLog._();

  static const int _maxLinhas = 300;

  /// Buffer de linhas (mais recente por último). Notifica o viewer.
  static final ValueNotifier<List<String>> linhas = ValueNotifier(const []);

  static bool _instalado = false;

  /// Intercepta debugPrint e FlutterError. Chamar uma vez no main, dentro de
  /// `if (kDebugMode)`. No-op se chamado de novo.
  static void instalar() {
    if (_instalado || !kDebugMode) return;
    _instalado = true;

    final debugPrintOriginal = debugPrint;
    debugPrint = (String? mensagem, {int? wrapWidth}) {
      if (mensagem != null && mensagem.trim().isNotEmpty) {
        registrar(mensagem);
      }
      debugPrintOriginal(mensagem, wrapWidth: wrapWidth);
    };

    final onErrorOriginal = FlutterError.onError;
    FlutterError.onError = (detalhes) {
      registrar('FLUTTER ERROR: ${detalhes.exceptionAsString()}');
      onErrorOriginal?.call(detalhes);
    };
  }

  /// Acrescenta uma linha com timestamp, respeitando o limite do buffer.
  static void registrar(String mensagem) {
    final agora = DateTime.now();
    final hora =
        '${agora.hour.toString().padLeft(2, '0')}:'
        '${agora.minute.toString().padLeft(2, '0')}:'
        '${agora.second.toString().padLeft(2, '0')}';
    final novas = [...linhas.value, '[$hora] $mensagem'];
    linhas.value = novas.length > _maxLinhas
        ? novas.sublist(novas.length - _maxLinhas)
        : novas;
  }

  static void limpar() => linhas.value = const [];

  /// Conteúdo completo para copiar/compartilhar.
  static String get textoCompleto => linhas.value.join('\n');
}
