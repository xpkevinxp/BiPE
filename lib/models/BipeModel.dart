class Bipe {


  final int idNegocio;
  final int idBilletera;
  final String contain;
  final String packageName;
  final String regex;

  Bipe.fromJson(Map<String, dynamic> json)
      : idNegocio = json['idNegocio'],
        idBilletera = json['idBilletera'],
        contain = json['contain'],
        packageName = json['packageName'],
        regex = json['regex'];
}