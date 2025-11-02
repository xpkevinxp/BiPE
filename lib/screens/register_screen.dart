import 'package:bipealerta/widgets/loader_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:animate_do/animate_do.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/gestures.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  int _currentStep = 1;

  final _businessNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _ownerLastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _verificationCodeController = TextEditingController();

  @override
  void dispose() {
    _businessNameController.dispose();
    _ownerNameController.dispose();
    _ownerLastNameController.dispose();
    _phoneController.dispose();
    _verificationCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleFirstStep() async {
    if (!_formKey.currentState!.validate()) return;

    // Mostramos el loader
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const LoadingDialog(
          message: "Enviando código de verificación...",
        );
      },
    );

    try {
      // Aquí iría la llamada a tu API para enviar el código
      final response = await http.post(
        Uri.parse(
            'https://apialert.c-centralizador.com/api/usuario/sendCodeWhatsapp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'Telefono': _phoneController.text,
        }),
      );
      Navigator.pop(context);
      if (response.statusCode == 200) {
        setState(() {
          _currentStep = 2;
        });
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['message']);
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSecondStep() async {
    if (!_formKey.currentState!.validate()) return;

    // Mostramos el loader
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const LoadingDialog(
          message: "Completando registro...",
        );
      },
    );

    try {
      final response = await http.post(
        Uri.parse(
            'https://apialert.c-centralizador.com/api/usuario/SaveUsuarioNegocio/v2'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "NombreNegocio": _businessNameController.text,
          "NombrePropietario": _ownerNameController.text,
          "ApellidoPropietario": _ownerLastNameController.text,
          "Telefono": _phoneController.text,
          "Code": _verificationCodeController.text
        }),
      );
      Navigator.pop(context);
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Registro exitoso, estaremos validando la informacion'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['message']);
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, colors: [
          Color(0xFF8A56FF),
          Color(0xFF9E73FF),
          Color(0xFFAB85FF),
        ])),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 80),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  FadeInUp(
                      duration: const Duration(milliseconds: 1000),
                      child: Text(
                        "Registro BiPe",
                        style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.bold),
                      )),
                  const SizedBox(height: 10),
                  FadeInUp(
                      duration: const Duration(milliseconds: 1300),
                      child: Text(
                        _currentStep == 1
                            ? "Complete sus datos"
                            : "Verificación de código",
                        style:
                            const TextStyle(color: Colors.white, fontSize: 18),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(60),
                        topRight: Radius.circular(60))),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(30),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: <Widget>[
                          const SizedBox(height: 60),
                          FadeInUp(
                              duration: const Duration(milliseconds: 1400),
                              child: Container(
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                          color: const Color(0xFFD4BFFF)
                                              .withOpacity(0.3),
                                          blurRadius: 20,
                                          offset: const Offset(0, 10))
                                    ]),
                                child: _currentStep == 1
                                    ? _buildFirstStepFields()
                                    : _buildSecondStepFields(),
                              )),
                          const SizedBox(height: 40),
                          FadeInUp(
                              duration: const Duration(milliseconds: 1600),
                              child: SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _isLoading
                                      ? null
                                      : (_currentStep == 1
                                          ? _handleFirstStep
                                          : _handleSecondStep),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF9E73FF),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(50),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 3,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Colors.white)),
                                        )
                                      : Text(
                                          _currentStep == 1
                                              ? "Continuar"
                                              : "Verificar código",
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 17),
                                        ),
                                ),
                              )),
                          if (_currentStep == 2) ...[
                            const SizedBox(height: 20),
                            FadeInUp(
                              duration: const Duration(milliseconds: 1700),
                              child: TextButton(
                                onPressed: () {
                                  setState(() {
                                    _currentStep = 1;
                                    _verificationCodeController.clear();
                                  });
                                },
                                child: const Text(
                                  "Volver atrás",
                                  style: TextStyle(
                                    color: Color(0xFFD4BFFF),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            if (_currentStep == 2) ...[
                              const SizedBox(height: 20),
                              FadeInUp(
                                duration: const Duration(milliseconds: 1800),
                                child: RichText(
                                  textAlign: TextAlign.center,
                                  text: TextSpan(
                                    text:
                                        '¿No recibiste el código vía WhatsApp? ',
                                    style: const TextStyle(color: Colors.black),
                                    children: <TextSpan>[
                                      TextSpan(
                                        text: 'Escríbenos y te ayudaremos',
                                        style: const TextStyle(
                                            color: Color(0xFF9E73FF),
                                            decoration:
                                                TextDecoration.underline),
                                        recognizer: TapGestureRecognizer()
                                          ..onTap = () {
                                            _launchWhatsApp();
                                          },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildFirstStepFields() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
          child: TextFormField(
            controller: _businessNameController,
            decoration: const InputDecoration(
                hintText: "Nombre del Negocio",
                hintStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none),
            validator: (value) =>
                value?.isEmpty ?? true ? 'Ingrese el nombre del negocio' : null,
          ),
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
          child: TextFormField(
            controller: _ownerNameController,
            decoration: const InputDecoration(
                hintText: "Nombre del Propietario",
                hintStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none),
            validator: (value) => value?.isEmpty ?? true
                ? 'Ingrese el nombre del propietario'
                : null,
          ),
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
          child: TextFormField(
            controller: _ownerLastNameController,
            decoration: const InputDecoration(
                hintText: "Apellido del Propietario",
                hintStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none),
            validator: (value) => value?.isEmpty ?? true
                ? 'Ingrese el apellido del propietario'
                : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
          child: Text(
            "Se le enviará un código por WhatsApp para validar su número. Por favor, ingrese un número de celular válido.",
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
        Container(
          padding: const EdgeInsets.all(10),
          child: TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            maxLength: 9, // Limitamos a 9 dígitos
            decoration: const InputDecoration(
              hintText: "Número de celular",
              hintStyle: TextStyle(color: Colors.grey),
              border: InputBorder.none,
              counterText: "", // Ocultamos el contador
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ingrese el número de celular';
              }
              if (value.length != 9) {
                return 'El número debe tener 9 dígitos';
              }
              // Verificamos que solo contenga números
              if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
                return 'Ingrese solo números';
              }
              // Verificamos que empiece con 9
              if (!value.startsWith('9')) {
                return 'El número debe empezar con 9';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSecondStepFields() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Te hemos enviado un código de verificación por WhatsApp',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
        Container(
          padding: const EdgeInsets.all(10),
          child: TextFormField(
            controller: _verificationCodeController,
            keyboardType: TextInputType.number,
            maxLength: 4,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, letterSpacing: 8),
            decoration: const InputDecoration(
              hintText: "Código",
              hintStyle: TextStyle(color: Colors.grey),
              border: InputBorder.none,
              counterText: "",
            ),
            validator: (value) {
              if (value?.isEmpty ?? true) return 'Ingrese el código';
              if (value!.length != 4) return 'El código debe tener 4 dígitos';
              return null;
            },
          ),
        ),
      ],
    );
  }

  void _launchWhatsApp() async {
    final whatsappUri = Uri.parse(
        "https://wa.me/51901089996?text=Hola,%20quisiera%20ayuda%20con%20mi%20registro");

    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo abrir WhatsApp'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al abrir WhatsApp'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}