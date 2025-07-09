import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_app/cache/shared_preferences_helper.dart';
import 'package:mobile_app/routes/app_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile_app/utils/utils.dart';
import 'gradient_underline_button.dart';
import 'gradient_cta_button.dart';
import 'app_logo.dart';
import 'glass_container.dart';

class AppNavbar extends StatefulWidget {
  final bool hideAcesseButton;
  final bool isFluxogramasPage;
  const AppNavbar(
      {super.key,
      this.hideAcesseButton = false,
      this.isFluxogramasPage = false});

  @override
  State<AppNavbar> createState() => _AppNavbarState();
}

class _AppNavbarState extends State<AppNavbar> {
  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Título/Logo à esquerda com padding
          const AppLogo(),
          // Links de navegação e botão agrupados à direita
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Na tela de upload histórico, mostra apenas o botão SAIR
              if (Utils.isCurrentRoute(context, '/upload-historico')) ...[
                if (SharedPreferencesHelper.currentUser != null) ...[
                  GradientUnderlineButton(
                    onPressed: () {
                      SharedPreferencesHelper.currentUser = null;
                      Supabase.instance.client.auth.signOut();
                      context.go('/login');
                    },
                    text: 'SAIR',
                  )
                ]
              ] else ...[
                // Para outras páginas, mostra a navegação normal
                GradientUnderlineButton(
                  onPressed: () {
                    context.go('/');
                  },
                  text: 'HOME',
                ),
                const SizedBox(width: 16),
                // Botão "MEUS FLUXOGRAMAS" só aparece quando:
                // 1. Usuário está logado
                // 2. Usuário já fez upload do fluxograma (dadosFluxograma != null)
                if (SharedPreferencesHelper.currentUser != null) ...[
                  const SizedBox(width: 16),
                  GradientUnderlineButton(
                    onPressed: () {
                      if (SharedPreferencesHelper
                              .currentUser!.dadosFluxograma !=
                          null) {
                        context.go('/meu-fluxograma');
                      } else {
                        context.go('/upload-historico');
                      }
                    },
                    text: 'MEUS FLUXOGRAMAS',
                  ),
                ],
                // Botões FLUXOGRAMAS e ASSISTENTE aparecem quando não está nas rotas de login/cadastro
                if (!Utils.isPublicRoute(context) &&
                    !Utils.routeStartsWith(context, '/fluxogramas')) ...[
                  const SizedBox(width: 16),
                  GradientUnderlineButton(
                    onPressed: () {
                      context.go('/fluxogramas');
                    },
                    text: 'FLUXOGRAMAS',
                  ),
                  if (!SharedPreferencesHelper.isAnonimo) ...[
                    const SizedBox(width: 16),
                    GradientUnderlineButton(
                      onPressed: () {
                        context.go('/assistente');
                      },
                      text: 'ASSISTENTE',
                    ),
                  ]
                ],
                // Botão "ACESSE NOSSO SISTEMA" aparece apenas na home quando não está logado
                if ((Utils.isHomeRoute(context) &&
                        SharedPreferencesHelper.currentUser == null) ||
                    SharedPreferencesHelper.isAnonimo) ...[
                  const SizedBox(width: 24),
                  GradientCTAButton(
                    onPressed: () {
                      context.go('/login');
                    },
                    text: 'ACESSE NOSSO SISTEMA',
                  ),
                ],
                // Botão "SAIR" aparece quando logado
                if (SharedPreferencesHelper.currentUser != null) ...[
                  const SizedBox(width: 16),
                  GradientUnderlineButton(
                    onPressed: () {
                      SharedPreferencesHelper.currentUser = null;
                      Supabase.instance.client.auth.signOut();
                      context.go('/login');
                    },
                    text: 'SAIR',
                  )
                ]
              ]
            ],
          ),
        ],
      ),
    );
  }
}
