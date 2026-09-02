import '../../../core/utils/tempo_relativo.dart';

/// Tempo relativo curto do inbox ("agora", "há 5 min", "há 3 h", "há 2
/// dias"; 7 dias ou mais vira data absoluta "dd/MM/yyyy"). Wrapper fino do
/// núcleo em core/utils/tempo_relativo.dart.
String formatarTempoRelativo(DateTime? data, {DateTime? agora}) =>
    tempoRelativo(data, agora: agora, diasParaDataAbsoluta: 7);
