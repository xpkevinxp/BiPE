class Usuario {
  final int id;
  final int idNegocio;
  final String nombre;
  final String nombreNegocio;
  final String nombrePlan;

  Usuario.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        idNegocio = json['idNegocio'],
        nombre = json['nombre'],
        nombreNegocio = json['nombreNegocio'],
        nombrePlan = json['nombrePlan'];
}