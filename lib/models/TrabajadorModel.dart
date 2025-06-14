class TrabajadorModel {
  int? id;
  String nombreTrabajador;
  String apellidoTrabajador;
  String usuario;
  String contrasena;
  int estado;

  TrabajadorModel({
    this.id,
    required this.nombreTrabajador,
    required this.apellidoTrabajador,
    required this.usuario,
    required this.contrasena,
    required this.estado,
  });

  TrabajadorModel.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        nombreTrabajador = json['nombreTrabajador'],
        apellidoTrabajador = json['apellidoTrabajador'],
        usuario = json['usuario'],
        contrasena = json['contrasena'],
        estado = json['estado'];

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'nombreTrabajador': nombreTrabajador,
      'apellidoTrabajador': apellidoTrabajador,
      'usuario': usuario,
      'contrasena': contrasena,
      'estado': estado,
    };
  }

  bool get activo => estado == 1;
  
  set activo(bool value) {
    estado = value ? 1 : 0;
  }
}
