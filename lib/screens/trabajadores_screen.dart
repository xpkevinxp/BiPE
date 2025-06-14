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
    TextEditingController _nombreController =
        TextEditingController(text: worker.nombreTrabajador);
    TextEditingController _apellidoController =
        TextEditingController(text: worker.apellidoTrabajador);
    TextEditingController _usuarioController =
        TextEditingController(text: worker.usuario);
    TextEditingController _contrasenaController =
        TextEditingController(text: worker.contrasena);
    bool _estado = worker.estado == 1; // Convert int to bool

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
                      controller: _nombreController,
                      decoration:
                          const InputDecoration(labelText: 'Nombre Trabajador'),
                    ),
                    TextField(
                      controller: _apellidoController,
                      decoration:
                          const InputDecoration(labelText: 'Apellido Trabajador'),
                    ),
                    TextField(
                      controller: _usuarioController,
                      decoration: const InputDecoration(labelText: 'Usuario'),
                    ),
                    TextField(
                      controller: _contrasenaController,
                      decoration: const InputDecoration(labelText: 'Contraseña'),
                      obscureText: true, // Hide password
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<bool>(
                      value: _estado,
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
                            _estado = newValue;
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
                      worker.nombreTrabajador = _nombreController.text;
                      worker.apellidoTrabajador = _apellidoController.text;
                      worker.usuario = _usuarioController.text;
                      worker.contrasena = _contrasenaController.text;
                      worker.activo = _estado;

                      // Update worker via API if id exists
                      if (worker.id != null) {
                        await _trabajadoresService.updateTrabajador(worker.id!, worker);
                      }
                      
                      Navigator.of(context).pop();
                      _trabajadoresService.showToast(context, 'Trabajador actualizado correctamente');
                      
                      // Refresh the worker list
                      setState(() {});
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
        
        setState(() {
          workers.remove(worker);
        });
        
        _trabajadoresService.showToast(context, '${worker.nombreTrabajador} ${worker.apellidoTrabajador} eliminado.');
      } catch (e) {
        _trabajadoresService.showToast(context, 'Error al eliminar trabajador: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trabajadores'),
        backgroundColor: Colors.blueAccent, // Example color
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTrabajadores,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : workers.isEmpty
              ? const Center(
                  child: Text(
                    'No hay trabajadores registrados',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: workers.length,
                  itemBuilder: (context, index) {
                    final worker = workers[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      child: ListTile(
                        title: Text('${worker.nombreTrabajador} ${worker.apellidoTrabajador}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Usuario: ${worker.usuario}'),
                            // Note: Displaying password is not recommended for security reasons.
                            // You might want to remove this or handle it differently.
                            Text('Contraseña: ${'*' * worker.contrasena.length}'),
                            Text('Estado: ${worker.activo ? 'Activo' : 'Baja'}'),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _editWorker(worker),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _deleteWorker(worker),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Implement add new worker functionality
          _trabajadoresService.showToast(context, 'Funcionalidad de agregar trabajador por implementar');
        },
        child: const Icon(Icons.add),
        backgroundColor: Colors.blueAccent,
      ),
    );
  }
}
