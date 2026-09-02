import 'package:go_router/go_router.dart';

import 'domain/redirect_importacao.dart';
import 'ui/importar_historico_screen.dart';

/// Rota da importação de histórico (fora do shell com bottom navigation,
/// como as telas de auth): onboarding pós-login e reenvio de PDF.
final List<RouteBase> importarHistoricoRoutes = [
  GoRoute(
    path: kRotaImportarHistorico,
    name: 'importar-historico',
    builder: (context, state) => const ImportarHistoricoScreen(),
  ),
];
