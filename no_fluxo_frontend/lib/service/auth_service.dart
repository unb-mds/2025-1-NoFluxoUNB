import 'package:flutter/material.dart';
import 'package:mobile_app/screens/auth/login_form.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final supabase = Supabase.instance.client;

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
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: displayName != null ? {'display_name': displayName} : null,
      );
      
      if (response.user != null) {
        return response.user; // Retorna o usuário em caso de sucesso
      }
      
      // Se não há usuário, lança exceção
      throw AuthException("Erro ao criar conta");
    } on AuthException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      throw AuthException("Erro inesperado: $e");
    }
  }

  // Método para login com Google (placeholder)
  Future<User?> signInWithGoogle() async {
    try {
      // Implementar quando tiver configurado o Google Auth no Supabase
      final result = await supabase.auth.signInWithOAuth(OAuthProvider.google);
      // signInWithOAuth returns a bool; you may want to check if it's true and then fetch the current user
      if (result) {
        return supabase.auth.currentUser;
      }
      throw AuthException("Login com Google ainda não está disponível");
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
        return response.user;
      }
      
      throw AuthException("Email ou senha inválidos");
    } on AuthException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
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
    try{
      await supabase.auth.signOut();
      if(!context.mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_)=> LoginForm(onToggleView: () {})));
    } catch (e){
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