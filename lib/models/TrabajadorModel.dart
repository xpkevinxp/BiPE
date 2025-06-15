class TrabajadorModel {
  int? id;
  String nombre;
  String usuario;
  String password;
  int idNegocio;  

  TrabajadorModel({
    this.id,
    required this.nombre,
    required this.usuario,
    required this.password,
    required this.idNegocio,
  });

  TrabajadorModel.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        nombre = json['nombre'],
        usuario = json['usuario'],
        password = json['password'],
        idNegocio = json['idNegocio'];

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'nombre': nombre,
      'usuario': usuario,
      'password': password,
      'idNegocio': idNegocio,
    };
  }
}
