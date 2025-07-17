import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_page.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final supabase = Supabase.instance.client;

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final usernameController = TextEditingController();

  String _authMode = 'login'; // 'login' | 'register'

  void toggleMode() {
    setState(() {
      _authMode = _authMode == 'login' ? 'register' : 'login';
    });
  }

  @override
  void initState() {
    super.initState();
    final session = supabase.auth.currentSession;
    if (session != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      });
    }
  }

  Future<void> handleAuth() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final username = usernameController.text.trim();

    try {
      if (_authMode == 'register') {
        await supabase.auth.signUp(
          email: email,
          password: password,
          data: {
            'username': username,
          }, // metadata del usuario
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Registro exitoso. Revisa tu correo y confirma tu cuenta antes de iniciar sesión.',
            ),
            duration: Duration(seconds: 5),
          ),
        );

        toggleMode();
        return;
      }

      final res = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = res.user;
      if (user == null) throw Exception('No se pudo iniciar sesión.');

      final existing = await supabase
          .from('users')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();

      if (existing == null) {
        final meta = user.userMetadata ?? {};
        await supabase.from('users').insert({
          'id': user.id,
          'username': meta['username'] ?? user.email!.split('@')[0],
        });
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_authMode == 'login' ? 'Iniciar Sesión' : 'Registro')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Correo electrónico'),
            ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Contraseña'),
              obscureText: true,
            ),
            if (_authMode == 'register') ...[
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(labelText: 'Nombre de usuario'),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: handleAuth,
              child: Text(_authMode == 'login' ? 'Iniciar Sesión' : 'Registrarse'),
            ),
            TextButton(
              onPressed: toggleMode,
              child: Text(
                _authMode == 'login'
                    ? '¿No tienes cuenta? Regístrate'
                    : '¿Ya tienes cuenta? Inicia sesión',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
