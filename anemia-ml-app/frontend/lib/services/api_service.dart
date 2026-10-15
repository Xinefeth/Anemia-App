// Servicio de comunicación con la API REST del backend.
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/nino.dart';
import '../models/valoracion.dart';

class ApiService {
  // Reemplazar por la URL del backend desplegado
  static const String baseUrl = 'http://10.0.2.2:8000';

  Future<Valoracion> valorarRiesgo(Nino nino) async {
    final respuesta = await http.post(
      Uri.parse('$baseUrl/api/predict'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(nino.toJson()),
    );

    if (respuesta.statusCode == 200) {
      return Valoracion.fromJson(jsonDecode(respuesta.body));
    } else {
      throw Exception('Error al obtener la valoración');
    }
  }
}
