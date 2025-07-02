import 'package:flutter/material.dart';
import '../../widgets/animated_background.dart';
import '../../widgets/app_navbar.dart';
import 'login_form.dart';
import 'signup_form.dart';
import 'package:google_fonts/google_fonts.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool isLogin = true;

  void toggleView() {
    setState(() {
      isLogin = !isLogin;
    });
  }

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
                              if (isLogin)
                                LoginForm(onToggleView: toggleView)
                              else
                                SignupForm(onToggleView: toggleView),
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
