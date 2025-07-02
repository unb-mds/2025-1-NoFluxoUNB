import 'package:flutter/material.dart';
import 'package:mobile_app/screens/auth/login_form.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final supabase = Supabase.instance.client;
  //sign up function
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
  
    //login function
  Future<String?> login(String email, String password) async {
    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user != null) {
        return null; // Sign up successful
      }
      return "Email ou senha inválidos";
    } on AuthException catch (e) {
      return e.message; // Return error message
    } catch (e) {
      return "Erro: $e";
    }
  }

  //logout function
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
}