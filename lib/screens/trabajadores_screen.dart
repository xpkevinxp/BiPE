import 'package:animate_do/animate_do.dart';
import 'package:bipealerta/models/TrabajadorModel.dart';
import 'package:bipealerta/services/trabajadores_service.dart';
import 'package:flutter/material.dart';

class TrabajadoresScreen extends StatefulWidget {
  const TrabajadoresScreen({Key? key}) : super(key: key);

  @override
  _TrabajadoresScreenState createState() => _TrabajadoresScreenState();
}

class _TrabajadoresScreenState extends State<TrabajadoresScreen> {
  final TrabajadoresService _trabajadoresService = TrabajadoresService();
  List<TrabajadorModel> workers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTrabajadores();
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
        TextEditingController(text: worker.nombreTrabajador);
    TextEditingController apellidoController =
        TextEditingController(text: worker.apellidoTrabajador);
    TextEditingController usuarioController =
        TextEditingController(text: worker.usuario);
    TextEditingController contrasenaController =
        TextEditingController(text: worker.contrasena);
    bool estado = worker.estado == 1; // Convert int to bool

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
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
                      controller: apellidoController,
                      decoration:
                          const InputDecoration(labelText: 'Apellido Trabajador'),
                    ),
                    TextField(
                      controller: usuarioController,
                      decoration: const InputDecoration(labelText: 'Usuario'),
                    ),
                    TextField(
                      controller: contrasenaController,
                      decoration: const InputDecoration(labelText: 'Contraseña'),
                      obscureText: true, // Hide password
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<bool>(
                      value: estado,
                      decoration: const InputDecoration(labelText: 'Estado'),
                      items: const [
                        DropdownMenuItem(
                          value: true,
                          child: Text('Activo'),
                        ),
                        DropdownMenuItem(
                          value: false,
                          child: Text('Baja'),
                        ),
                      ],
                      onChanged: (bool? newValue) {
                        if (newValue != null) {
                          setState(() {
                            estado = newValue;
                          });
                        }
                      },
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
                      worker.nombreTrabajador = nombreController.text;
                      worker.apellidoTrabajador = apellidoController.text;
                      worker.usuario = usuarioController.text;
                      worker.contrasena = contrasenaController.text;
                      worker.activo = estado;

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
          content: Text('¿Estás seguro de que deseas eliminar a ${worker.nombreTrabajador} ${worker.apellidoTrabajador}?'),
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

        _trabajadoresService.showToast(context, '${worker.nombreTrabajador} ${worker.apellidoTrabajador} eliminado.');
      } catch (e) {
        _trabajadoresService.showToast(context, 'Error al eliminar trabajador: $e');
      }
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
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    // TODO: Implement add new worker functionality
                                     _trabajadoresService.showToast(context, 'Funcionalidad de agregar trabajador por implementar');
                                  },
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
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30), // Adjust padding
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
                                      '${worker.nombreTrabajador} ${worker.apellidoTrabajador}',
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
                                          'Contraseña: ${'*' * worker.contrasena.length}',
                                          style: TextStyle(color: Colors.grey.shade700),
                                          ),
                                        const SizedBox(height: 4), // Add space
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: worker.activo ? Colors.green.shade100 : Colors.red.shade100,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'Estado: ${worker.activo ? 'Activo' : 'Baja'}',
                                            style: TextStyle(
                                               color: worker.activo ? Colors.green.shade800 : Colors.red.shade800,
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
                                          icon: Icon(Icons.edit, color: Colors.blueAccent),
                                          onPressed: () => _editWorker(worker),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.delete, color: Colors.redAccent),
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
            ),
          ],
        ),
      ),
       floatingActionButton: workers.isNotEmpty ? FloatingActionButton( // Only show FAB if there are workers
        onPressed: () {
          // TODO: Implement add new worker functionality
          _trabajadoresService.showToast(context, 'Funcionalidad de agregar trabajador por implementar');
        },
        child: const Icon(Icons.add, color: Colors.white),
        backgroundColor: const Color(0xFF8A56FF), // Color del logo
        elevation: 6,
      ) : null, // Hide FAB if no workers are registered
    );
  }
}
