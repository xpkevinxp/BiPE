import 'package:bipealerta/models/TrabajadorModel.dart';
import 'package:flutter/material.dart';

class TrabajadoresScreen extends StatefulWidget {
  const TrabajadoresScreen({Key? key}) : super(key: key);

  @override
  _TrabajadoresScreenState createState() => _TrabajadoresScreenState();
}

class _TrabajadoresScreenState extends State<TrabajadoresScreen> {

  List<TrabajadorModel> workers = [
  ];
  
  // Function to show the edit worker dialog
  void _editWorker(TrabajadorModel worker) {
    TextEditingController _nombreController =
        TextEditingController(text: worker.nombreTrabajador);
    TextEditingController _apellidoController =
        TextEditingController(text: worker.ApellidoTrabajador);
    TextEditingController _usuarioController =
        TextEditingController(text: worker.Usuario);
    TextEditingController _contrasenaController =
        TextEditingController(text: worker.Contrasena);
    bool _estado = worker.estado == 1; // Convert int to bool

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Worker'),
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
                      _estado = newValue;
                    }
                  },
                ),
 Text('Estado: ${worker.estado ? 'Activo' : 'Baja'}'),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () {
                setState(() {
                  // Update the worker's information
                  worker.nombreTrabajador = _nombreController.text;
                  worker.apellidoTrabajador = _apellidoController.text;
                  worker.usuario = _usuarioController.text;
                  worker.contrasena = _contrasenaController.text;
                  worker.activo = _estado;
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Function to delete a worker
  void _deleteWorker(TrabajadorModel worker) {
    // Implement your delete logic here (e.g., API call, remove from list)
    setState(() {
      workers.remove(worker);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${worker.nombreTrabajador} ${worker.apellidoTrabajador} deleted.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trabajadores'),
        backgroundColor: Colors.blueAccent, // Example color
      ),
      body: ListView.builder(
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
                  Text('Contraseña: ${worker.contrasena}'),
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
    );
  }
}
