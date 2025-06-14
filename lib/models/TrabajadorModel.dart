class TrabajadorModel {
  final String nombreTrabajador;
  final String ApellidoTrabajador;
  final String Usuario;
  final String Contrasena;
  final int estado;

  TrabajadorModel.fromJson(Map<String, dynamic> json)
      : nombreTrabajador = json['nombreTrabajador'],
        ApellidoTrabajador = json['ApellidoTrabajador'],
        Usuario = json['Usuario'],
        Contrasena = json['Contraseña'],
        estado = json['estado'];
}
