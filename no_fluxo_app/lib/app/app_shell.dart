import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/dev/dev_panel.dart';
import '../core/theme/app_colors.dart';
import '../features/notificacoes/providers/notificacoes_provider.dart';

/// Shell com bottom navigation de 5 abas (IndexedStack preserva o estado de
/// cada aba ao trocar).
class AppShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final naoLidas = ref.watch(unreadCountProvider);
    return Scaffold(
      // Console de logs do modo dev, acessível de qualquer aba (só debug).
      body: !kDebugMode
          ? navigationShell
          : Stack(
              children: [
                navigationShell,
                Positioned(
                  top: 4,
                  right: 4,
                  child: SafeArea(
                    child: IconButton(
                      tooltip: 'Logs do app (modo dev)',
                      icon: Icon(
                        Icons.bug_report_outlined,
                        size: 18,
                        color: AppColors.mutedForeground.withValues(alpha: 0.6),
                      ),
                      onPressed: () => mostrarDevLogs(context),
                    ),
                  ),
                ),
              ],
            ),
      // Fonte de acessibilidade ampliada não pode quebrar os rótulos da barra
      // em duas linhas, então o scaling é limitado só aqui.
      bottomNavigationBar: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.2,
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) => navigationShell.goBranch(
            index,
            // Tocar na aba atual volta para a raiz da aba.
            initialLocation: index == navigationShell.currentIndex,
          ),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.account_tree_outlined),
              selectedIcon: Icon(Icons.account_tree),
              label: 'Fluxograma',
            ),
            const NavigationDestination(
              icon: Icon(Icons.groups_outlined),
              selectedIcon: Icon(Icons.groups),
              label: 'Turmas',
            ),
            const NavigationDestination(
              icon: Icon(Icons.calendar_view_week_outlined),
              selectedIcon: Icon(Icons.calendar_view_week),
              label: 'Grade',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: naoLidas > 0,
                label: Text(naoLidas > 99 ? '99+' : '$naoLidas'),
                child: const Icon(Icons.notifications_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: naoLidas > 0,
                label: Text(naoLidas > 99 ? '99+' : '$naoLidas'),
                child: const Icon(Icons.notifications),
              ),
              // Rótulo curto de propósito: "Notificações" quebra em duas
              // linhas com 5 abas em telas estreitas.
              label: 'Avisos',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}
