import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/animated_background.dart';
import '../../widgets/app_navbar.dart';
import 'login_form.dart';
import 'signup_form.dart';
import 'package:google_fonts/google_fonts.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, this.isLogin = true});
  
  final bool isLogin;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const AnimatedBackground(),
          SafeArea(
            child: DefaultTextStyle(
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
              child: Column(
                children: [
                  const AppNavbar(),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 30),
                              if (widget.isLogin)
                                LoginForm(onToggleView: () => context.go('/signup'))
                              else
                                SignupForm(onToggleView: () => context.go('/login')),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
