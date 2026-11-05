/// Usuario autenticado (personal de salud).
class Usuario {
  final int id;
  final String nombre;
  final String usuario;
  final String rol;

  const Usuario({required this.id, required this.nombre, required this.usuario, required this.rol});

  factory Usuario.fromJson(Map<String, dynamic> j) => Usuario(
        id: j['id_usuario'] as int,
        nombre: j['nombre'] as String,
        usuario: j['usuario'] as String,
        rol: j['rol'] as String,
      );

  Map<String, dynamic> toJson() =>
      {'id_usuario': id, 'nombre': nombre, 'usuario': usuario, 'rol': rol};

  /// Iniciales para el avatar, p. ej. "Dr. Diego Jara" -> "DJ".
  String get iniciales {
    final partes = nombre
        .split(' ')
        .where((p) => p.isNotEmpty && !p.endsWith('.'))
        .toList();
    if (partes.isEmpty) return '?';
    final a = partes.first[0];
    final b = partes.length > 1 ? partes.last[0] : '';
    return (a + b).toUpperCase();
  }
}
