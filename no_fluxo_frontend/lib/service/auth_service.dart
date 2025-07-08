import 'dart:async';
import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:mobile_app/environment.dart';
import 'package:mobile_app/screens/auth/login_form.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../cache/shared_preferences_helper.dart';
import '../models/user_model.dart';

final log = Logger('AuthService');

class AuthService {
  final supabase = Supabase.instance.client;

  static Future<Either<String, UserModel>> databaseSearchUser(
      String email) async {
    try {
      final response = await http.get(
        Uri.parse('${Environment.apiUrl}/users/get-user-by-email?email=$email'),
      );

      if (response.statusCode == 200) {
        var user = UserModel.fromJson(jsonDecode(response.body));
        user.token = Supabase.instance.client.auth.currentSession?.accessToken;
        return Right(user);
      }

      return Left(response.body);
    } catch (e, st) {
      log.severe(e, st);
      return Left(e.toString());
    }
  }

  static Future<Either<String, UserModel>>
      databaseRegisterUserWhenLoggedInWithGoogle(
          String email, String nomeCompleto) async {
    try {
      final response = await http.post(
        Uri.parse('${Environment.apiUrl}/users/register-user-with-google'),
        body: {
          'email': email,
          'nome_completo': nomeCompleto,
        },
      );

      if (response.statusCode == 200) {
        return Right(UserModel.fromJson(jsonDecode(response.body)));
      }

      return Left(response.body);
    } catch (e, st) {
      log.severe(e, st);
      return Left(e.toString());
    }
  }

  // Método original signup mantido
  Future<String?> signup(String email, String password) async {
    try {
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
      );
      if (response.user != null) {
        return null; // Sign up successful
      }
      return "Algum erro ao criar conta";
    } on AuthException catch (e) {
      return e.message; // Return error message
    } catch (e) {
      return "Erro: $e";
    }
  }

  // Novo método para compatibilidade com SignupForm
  Future<User?> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      // First, create the user in Supabase Auth
      final authResponse = await supabase.auth.signUp(
        email: email,
        password: password,
        data: displayName != null ? {'display_name': displayName} : null,
      );

      if (authResponse.user == null) {
        throw AuthException("Erro ao criar conta no Supabase");
      }

      // Then, register the user in our backend
      final response = await http.post(
        Uri.parse('${Environment.apiUrl}/users/registrar-user-with-email'),
        body: {
          'email': email,
          'nome_completo': displayName ?? email.split('@')[0],
        },
      );

      if (response.statusCode != 200) {
        // If backend registration fails, delete the Supabase auth user
        await supabase.auth.signOut();
        throw AuthException(response.body);
      }

      return authResponse.user;
    } on AuthException catch (e) {
      log.severe('Auth error during signup', e);
      throw AuthException(e.message);
    } catch (e, st) {
      log.severe('Unexpected error during signup', e, st);
      throw AuthException("Erro inesperado: $e");
    }
  }

  // Método para login com Google (placeholder)
  Future<Either<String, User?>> signInWithGoogle() async {
    try {
      Completer<Either<String, User?>> completer =
          Completer<Either<String, User?>>();
      String? error;

      StreamSubscription<AuthState> subscription =
          supabase.auth.onAuthStateChange.listen((event) async {
        await supabase.auth.signInWithOAuth(OAuthProvider.google,
            redirectTo: "http://localhost:5000/",
            queryParams: {
              "prompt": "consent",
            });

        ////print("AuthChangeEvent: ${event.event}");
        if (event.event == AuthChangeEvent.signedIn && !completer.isCompleted) {
          completer.complete(Right(supabase.auth.currentUser!));
        }
      }, onError: (err) async {
        if (err.toString().contains("Invalid auth token")) {
          await supabase.auth.signOut();
        }

        error = err.toString();
        if (!completer.isCompleted) {
          completer.complete(Left(error!));
        }
      }, onDone: () {
        ////print("------- DONE ------");
      });

      final result = await completer.future;
      await subscription.cancel();
      return result;
    } catch (e) {
      throw AuthException("Erro no login com Google: $e");
    }
  }

  // Método original login mantido
  Future<String?> login(String email, String password) async {
    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user != null) {
        // Fetch user data from backend and set in SharedPreferences
        final result = await databaseSearchUser(email);
        final error = await result.fold(
          (error) async => error,
          (userFromDb) async {
            print(
                '[DEBUG] Salvando usuário em SharedPreferencesHelper.currentUser:');
            print(userFromDb);
            SharedPreferencesHelper.currentUser = userFromDb;
            print('[DEBUG] Usuário salvo com sucesso!');
            return null;
          },
        );

        if (error != null) {
          // NÃO faz signOut automático, apenas retorna erro
          // await supabase.auth.signOut(); // Removido
          return 'Usuário autenticado, mas não encontrado no banco de dados interno. Contate o suporte.';
        }
        return null; // Login successful
      }
      return "Email ou senha inválidos";
    } on AuthException catch (e) {
      return e.message; // Return error message
    } catch (e) {
      return "Erro: $e";
    }
  }

  // Novo método para compatibilidade com outras telas
  Future<User?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        // Fetch user data from backend and set in SharedPreferences
        final result = await databaseSearchUser(email);
        await result.fold(
          (error) async {
            throw AuthException(error);
          },
          (userFromDb) async {
            SharedPreferencesHelper.currentUser = userFromDb;
          },
        );

        return response.user;
      }

      throw AuthException("Email ou senha inválidos");
    } on AuthException catch (e) {
      log.severe('Auth error during login', e);
      throw AuthException(e.message);
    } catch (e, st) {
      log.severe('Unexpected error during login', e, st);
      throw AuthException("Erro inesperado: $e");
    }
  }

  // Método para obter usuário atual
  User? getCurrentUser() {
    return supabase.auth.currentUser;
  }

  // Método para verificar se usuário está logado
  bool isLoggedIn() {
    return supabase.auth.currentUser != null;
  }

  // Stream para escutar mudanças no estado de autenticação
  Stream<AuthState> get authStateChanges {
    return supabase.auth.onAuthStateChange;
  }

  // Método original logout mantido
  Future<void> logout(BuildContext context) async {
    try {
      await supabase.auth.signOut();
      if (!context.mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(
          MaterialPageRoute(builder: (_) => LoginForm(onToggleView: () {})));
    } catch (e) {
      print("Erro ao fazer logout: $e");
    }
  }

  // Método de logout simplificado (sem navegação)
  Future<void> signOut() async {
    try {
      await supabase.auth.signOut();
    } catch (e) {
      throw AuthException("Erro ao fazer logout: $e");
    }
  }
}
