import 'package:animate_do/animate_do.dart';
import 'package:bipealerta/models/TrabajadorModel.dart';
import 'package:bipealerta/services/trabajadores_service.dart';
import 'package:bipealerta/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class TrabajadoresScreen extends StatefulWidget {
  const TrabajadoresScreen({super.key});

  @override
  _TrabajadoresScreenState createState() => _TrabajadoresScreenState();
}

class _TrabajadoresScreenState extends State<TrabajadoresScreen> {
  final TrabajadoresService _trabajadoresService = TrabajadoresService();
  final AuthService _authService = AuthService();
  List<TrabajadorModel> workers = [];
  bool _isLoading = false;
  int? _idPlan;

  @override
  void initState() {
    super.initState();
    _loadTrabajadores();
    _loadUserPlan();
  }

  Future<void> _loadUserPlan() async {
    try {
      final idPlan = await _authService.getIdPlan();
      setState(() {
        _idPlan = idPlan;
      });
    } catch (e) {
      print('Error cargando plan del usuario: $e');
    }
  }

  Future<void> _loadTrabajadores() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final trabajadores = await _trabajadoresService.getTrabajadores();
      setState(() {
        workers = trabajadores;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        _trabajadoresService.showToast(context, 'Error al cargar trabajadores: $e');
      }
    }
  }

  // Function to show the edit worker dialog
  void _editWorker(TrabajadorModel worker) {
    TextEditingController nombreController =
        TextEditingController(text: worker.nombre);
    TextEditingController usuarioController =
        TextEditingController(text: worker.usuario);
    TextEditingController passwordController =
        TextEditingController(text: worker.password);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Editar Trabajador'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                TextField(
                  controller: nombreController,
                  decoration:
                      const InputDecoration(labelText: 'Nombre Trabajador'),
                ),
                TextField(
                  controller: usuarioController,
                  decoration: const InputDecoration(labelText: 'Usuario'),
                ),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: 'Contraseña'),
                  obscureText: true, // Hide password
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Guardar'),
              onPressed: () async {
                try {
                  // Update the worker's information
                  worker.nombre = nombreController.text;
                  worker.usuario = usuarioController.text;
                  worker.password = passwordController.text;

                  // Update worker via API if id exists
                  if (worker.id != null) {
                    await _trabajadoresService.updateTrabajador(worker.id!, worker);
                  }

                  Navigator.of(context).pop();
                  _trabajadoresService.showToast(context, 'Trabajador actualizado correctamente');

                  // Refresh the worker list
                  _loadTrabajadores(); // Reload the list after updating
                } catch (e) {
                  _trabajadoresService.showToast(context, 'Error al actualizar trabajador: $e');
                }
              },
            ),
          ],
        );
      },
    );
  }

  // Function to delete a worker
  void _deleteWorker(TrabajadorModel worker) async {
    bool confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar eliminación'),
          content: Text('¿Estás seguro de que deseas eliminar a ${worker.nombre}?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Eliminar'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    ) ?? false;

    if (confirm) {
      try {
                 // Delete worker via API if id exists
         if (worker.id != null) {
           await _trabajadoresService.deleteTrabajador(worker.id!);
         }

        _loadTrabajadores(); // Reload the list after deleting

        _trabajadoresService.showToast(context, '${worker.nombre} eliminado.');
      } catch (e) {
        _trabajadoresService.showToast(context, 'Error al eliminar trabajador: $e');
      }
    }
  }

  // Método para validar si se puede agregar un nuevo trabajador
  bool _canAddNewWorker() {
    if (_idPlan == null) return false;
    
    // Si el plan es 1 o 2, solo puede tener 1 trabajador
    if (_idPlan == 1 || _idPlan == 2) {
      return workers.isEmpty;
    }
    
    // Para otros planes, puede tener varios trabajadores
    return true;
  }

  // Método para obtener el mensaje de restricción para agregar trabajadores
  String _getRestrictionMessage() {
    if (_idPlan == null) return 'No se pudo obtener información del plan';
    
    if (_idPlan == 1 || _idPlan == 2) {
      if (workers.isNotEmpty) {
        return 'Tu plan actual solo permite 1 trabajador. Para agregar más trabajadores, contacta con soporte para mejorar tu plan.';
      }
    }
    
    return '';
  }

  // Método para mostrar formulario de agregar trabajador
  void _showAddWorkerForm() {
    TextEditingController nombreController = TextEditingController();
    TextEditingController usuarioController = TextEditingController();
    TextEditingController passwordController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Agregar Trabajador'),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    TextField(
                      controller: nombreController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre Completo',
                        hintText: 'Ingresa el nombre completo',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: usuarioController,
                      decoration: const InputDecoration(
                        labelText: 'Usuario',
                        hintText: 'Ingresa el nombre de usuario',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                        hintText: 'Ingresa la contraseña',
                      ),
                      obscureText: true,
                    ),
                    if (isLoading) ...[
                      const SizedBox(height: 16),
                      const Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text('Creando trabajador...'),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: isLoading ? null : () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: isLoading ? null : () async {
                    if (nombreController.text.trim().isEmpty ||
                        usuarioController.text.trim().isEmpty ||
                        passwordController.text.trim().isEmpty) {
                      _trabajadoresService.showToast(
                        context,
                        'Todos los campos son obligatorios',
                      );
                      return;
                    }

                    setState(() {
                      isLoading = true;
                    });

                    try {
                      final idNegocio = await _authService.getIdNegocio();
                      if (idNegocio == null) {
                        throw Exception('No se pudo obtener información del negocio');
                      }

                      final newWorker = TrabajadorModel(
                        nombre: nombreController.text.trim(),
                        usuario: usuarioController.text.trim(),
                        password: passwordController.text.trim(),
                        idNegocio: idNegocio,
                      );

                      await _trabajadoresService.createTrabajador(newWorker);

                      if (mounted) {
                        Navigator.of(context).pop();
                        _trabajadoresService.showToast(
                          context,
                          'Trabajador creado exitosamente',
                        );
                        _loadTrabajadores(); // Recargar la lista
                      }
                    } catch (e) {
                      if (mounted) {
                        setState(() {
                          isLoading = false;
                        });
                        _trabajadoresService.showToast(
                          context,
                          'Error al crear trabajador: $e',
                        );
                      }
                    }
                  },
                  child: const Text('Crear'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Método para abrir WhatsApp y contactar soporte
  void _abrirWhatsAppUpgrade() async {
    final whatsappUri = Uri.parse(
        "https://wa.me/51930429628?text=Hola,%20quisiera%20información%20sobre%20los%20planes%20premium");

    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          _trabajadoresService.showToast(context, 'No se pudo abrir WhatsApp');
        }
      }
    } catch (e) {
      if (mounted) {
        _trabajadoresService.showToast(context, 'Error al abrir WhatsApp');
      }
    }
  }

  // Método para mostrar diálogo informativo sobre la restricción
  void _showAddWorkerDialog() {
    if (_canAddNewWorker()) {
      _showAddWorkerForm();
    } else {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange.shade600),
                const SizedBox(width: 8),
                const Text('Límite de trabajadores'),
              ],
            ),
            content: Text(_getRestrictionMessage()),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Entendido'),
              ),
              if (_idPlan == 1 || _idPlan == 2)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _abrirWhatsAppUpgrade();
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF8A56FF),
                  ),
                  child: const Text('Mejorar Plan', style: TextStyle(color: Colors.white)),
                ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, colors: [
          Color(0xFF8A56FF), // Color principal del logo
          Color(0xFF9E73FF), // Un poco más claro
          Color(0xFFAB85FF), // Aún más claro
        ])),
        child: Column(
          children: [
            const SizedBox(height: 60),
            // Header con título y botón de regreso/refrescar
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                       IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                      const SizedBox(width: 10), // Add spacing
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FadeInUp(
                              duration: const Duration(milliseconds: 1000),
                              child: const Text(
                                "Trabajadores",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold),
                              )),
                          const SizedBox(height: 5),
                          FadeInUp(
                              duration: const Duration(milliseconds: 1300),
                              child: const Text(
                                "Gestión de Personal", // Subtitle
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 18),
                              )),
                        ],
                      ),
                    ],
                  ),
                  FadeInUp(
                       duration: const Duration(milliseconds: 1000),
                       child: IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        onPressed: _loadTrabajadores,
                      ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20), // Add some space between header and content area

            // Contenido principal con efecto curvo
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(60),
                      topRight: Radius.circular(60)),
                ),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : workers.isEmpty
                                                ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.person_off_outlined,
                                  size: 48,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No hay trabajadores registrados',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (_idPlan != null && (_idPlan == 1 || _idPlan == 2))
                                  Text(
                                    'Tu plan permite 1 trabajador',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade500,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: _showAddWorkerDialog,
                                  icon: const Icon(Icons.add, color: Colors.white),
                                  label: const Text('Agregar Trabajador', style: TextStyle(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF8A56FF), // Color del logo
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            children: [
                              // Información del plan si es limitado
                              if (_idPlan != null && (_idPlan == 1 || _idPlan == 2))
                                Container(
                                  margin: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.blue.shade200,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        color: Colors.blue.shade600,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Plan Básico',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue.shade800,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Solo puedes tener 1 trabajador a la vez',
                                              style: TextStyle(
                                                color: Colors.blue.shade700,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // Lista de trabajadores
                              Expanded(
                                child: ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                  itemCount: workers.length,
                            itemBuilder: (context, index) {
                              final worker = workers[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 15.0), // Add spacing between cards
                                elevation: 2, // Add subtle shadow
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12), // Rounded corners
                                ),
                                child: Padding( // Add padding inside the card
                                   padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero, // Remove default ListTile padding
                                    title: Text(
                                      worker.nombre,
                                       style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade800,
                                       ),
                                      ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4), // Add space
                                        Text(
                                          'Usuario: ${worker.usuario}',
                                           style: TextStyle(color: Colors.grey.shade700),
                                          ),
                                        // Note: Displaying password is not recommended for security reasons.
                                        // You might want to remove this or handle it differently.
                                        Text(
                                          'Contraseña: ${'*' * worker.password.length}',
                                          style: TextStyle(color: Colors.grey.shade700),
                                          ),
                                        const SizedBox(height: 4), // Add space
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade100,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'Estado: Activo',
                                            style: TextStyle(
                                               color: Colors.green.shade800,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.blueAccent),
                                          onPressed: () => _editWorker(worker),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                                          onPressed: () => _deleteWorker(worker),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                                ),
                              ),
                            ],
                          ),
              ),
            ),
          ],
        ),
      ),
       floatingActionButton: workers.isNotEmpty ? FloatingActionButton( // Only show FAB if there are workers
        onPressed: _showAddWorkerDialog,
        backgroundColor: const Color(0xFF8A56FF), // Color del logo
        elevation: 6,
        child: const Icon(Icons.add, color: Colors.white),
      ) : null, // Hide FAB if no workers are registered
    );
  }
}
