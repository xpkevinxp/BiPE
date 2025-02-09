import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

 @override
 _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
 final _formKey = GlobalKey<FormState>();
 final _usernameController = TextEditingController();
 final _passwordController = TextEditingController();
 final _authService = AuthService();
 bool _isLoading = false;

 Future<void> _login() async {
  if (_formKey.currentState!.validate()) {
    try {
      setState(() => _isLoading = true);

      // Verificar conectividad primero
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        throw Exception('No hay conexión a internet. Por favor verifica tu conexión.');
      }
      
      final success = await _authService.login(
        _usernameController.text,
        _passwordController.text,
      );

      if (success) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Usuario o contraseña incorrectos'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

 Widget _buildTitle() {
    return Column(
      children: [
        Text(
          'YapeAlerta',
          style: GoogleFonts.montserrat(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF896FD6)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        const Text(
          'Bienvenido a tu app de monitoreo de Yape',
          style: TextStyle(
            fontSize: 18,
            color: Color(0xFF696868),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
      ],
    );
  }


 @override
 Widget build(BuildContext context) {
   return Scaffold(
     backgroundColor: const Color(0xFFF6F5FC),
     body: SafeArea(
       child: SingleChildScrollView(
         child: Padding(
           padding: const EdgeInsets.all(24.0),
           child: Form(
             key: _formKey,
             child: Column(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 const SizedBox(height: 80),
                 _buildTitle(),
                 TextFormField(
                   controller: _usernameController,
                   decoration: InputDecoration(
                     labelText: 'Usuario',
                     labelStyle: const TextStyle(
                        color: Color(0xFF93889D),
                        fontWeight: FontWeight.w600,
                      ),
                     filled: true,
                     fillColor: Colors.white,
                     border: OutlineInputBorder(
                       borderRadius: BorderRadius.circular(12.0),
                       borderSide: BorderSide.none,
                     ),
                   ),
                   validator: (value) =>
                       value?.isEmpty ?? true ? 'Ingrese su usuario' : null,
                 ),
                 const SizedBox(height: 24),
                 TextFormField(
                   controller: _passwordController,
                   decoration: InputDecoration(
                     labelText: 'Contraseña',
                     labelStyle: const TextStyle(
                        color: Color(0xFF93889D),
                        fontWeight: FontWeight.w600,
                      ),
                     filled: true,
                     fillColor: Colors.white,
                     border: OutlineInputBorder(
                       borderRadius: BorderRadius.circular(12.0),
                       borderSide: BorderSide.none,
                     ),
                   ),
                   obscureText: true,
                   validator: (value) => value?.isEmpty ?? true
                       ? 'Ingrese su contraseña'
                       : null,
                 ),
                 const SizedBox(height: 32),
                 SizedBox(
                   width: double.infinity,
                   height: 55,
                 child: ElevatedButton(
                   onPressed: _isLoading ? null : _login,
                   style: ElevatedButton.styleFrom(
                     backgroundColor: const Color(0xFF896FD6),
                     elevation: 0,
                   ),
                   child: _isLoading
                     ? const SizedBox(
                         height: 20,
                         width: 20,
                         child: CircularProgressIndicator(
                          strokeWidth: 3,
                           valueColor:
                             AlwaysStoppedAnimation<Color>(Colors.white)
                         ),
                       )
                     : const Text('Iniciar Sesión',
                     style: TextStyle(
                       fontSize: 17,
                       fontWeight: FontWeight.w600,
                       ),
                     ),
                 ),
               ),
             ],
           ),
         ),
       ),
     ),
   ));
 }
}