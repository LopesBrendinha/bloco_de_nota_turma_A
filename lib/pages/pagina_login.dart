import 'package:bloco_de_nota_turma_a/pages/pagina_notas.dart';
import 'package:bloco_de_nota_turma_a/pages/pagina_cadastro.dart';
import 'package:bloco_de_nota_turma_a/services/auth_service.dart';
import 'package:flutter/material.dart';

class PaginaLogin extends StatefulWidget {
  const PaginaLogin({super.key});

  @override
  State<PaginaLogin> createState() => _PaginaLoginState();
}

class _PaginaLoginState extends State<PaginaLogin> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final AuthService authService = AuthService();

  bool loading = false;
  bool obscurePassword = true;

  Future<void> login() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      showMessage("Preencha todos os campos");
      return;
    }
    setState(() {
      loading = true;
    });

    try {
      final user = await authService.login(
        emailController.text.trim(),
        passwordController.text.trim(),
      );

      if (user != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => PaginaNotas()),
        );
      }
    } catch (e) {
      showMessage("Não foi possível realizar o login");
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();

    super.dispose();
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      color: Color(0xFFE8DDF8),
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Icon(
                      Icons.edit_note_rounded,
                      size: 45,
                      color: Color(0xff6c4ab6),
                    ),
                  ),
                ),
                SizedBox(height: 35),
                Text(
                  "Olá!",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff292333),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Entre para acessar suas notas.',
                  style: TextStyle(fontSize: 16, color: Color(0xff77717f)),
                ),
                SizedBox(height: 35),
                Text(
                  "E-mail",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xff40394a),
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: "seu@email.com",
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "Senha",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xff40394a),
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    hintText: "Digite sua senha",
                    prefixIcon: Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          obscurePassword = !obscurePassword;
                        });
                      },
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 30),
                ElevatedButton(
                  onPressed: loading ? null : login,
                  child: loading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          "Entrar",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                SizedBox(height: 20),
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => PaginaCadastro()),
                      );
                    },
                    child: Text("Ainda não possui uma conta? Cadastre-se", ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
