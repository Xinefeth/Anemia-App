import 'dart:async';

import 'package:flutter/material.dart';

import '../models/valoracion.dart';
import '../services/api_service.dart';
import '../services/app_state.dart';
import '../services/auth_service.dart';
import '../services/db_service.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';
import '../utils.dart';
import '../widgets/estado_error.dart';
import '../widgets/header_gradiente.dart';
import '../widgets/item_valoracion.dart';
import 'detalle_screen.dart';

/// Pantalla 5 · Historial con filtros por nivel y búsqueda (HU07, HU08).
class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  static const _niveles = ['Todos', 'Alto', 'Medio', 'Bajo'];

  final _busqueda = TextEditingController();
  Timer? _debounce;
  String _nivel = 'Todos';
  bool _mostrarBusqueda = false;

  List<Valoracion> _lista = [];
  bool _cargando = true;
  bool _desdeCache = false;
  String? _error;
  int _pendientes = 0;
  int _conError = 0;

  @override
  void initState() {
    super.initState();
    datosCambiaron.addListener(_cargar);
    _cargar();
  }

  @override
  void dispose() {
    datosCambiaron.removeListener(_cargar);
    _debounce?.cancel();
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _contarPendientes() async {
    final id = AuthService.instancia.usuario?.id;
    if (id == null) return;
    final p = await DbService.instancia.pendientes(id);
    if (mounted) setState(() {
      _pendientes = p.length;
      _conError = p.where((e) => e.error != null).length;
    });
  }

  Future<void> _cargar({bool sincronizar = true}) async {
    final uid = AuthService.instancia.usuario?.id;
    if (_lista.isEmpty) setState(() => _cargando = true);
    // Primero se intenta enviar lo guardado sin conexión.
    if (sincronizar && uid != null) {
      await SyncService.sincronizar(uid);
    }
    await _contarPendientes();
    final nivel = _nivel == 'Todos' ? null : _nivel;
    final texto = _busqueda.text.trim();
    try {
      final lista = await ApiService.instancia.historial(nivel: nivel, busqueda: texto);
      if (nivel == null && texto.isEmpty) await DbService.instancia.reemplazarCache(lista);
      if (mounted) setState(() {
        _lista = lista;
        _desdeCache = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (e.sinConexion) {
        // Sin conexión: se muestra la última copia local, filtrada en el teléfono.
        final cache = await DbService.instancia.leerCache();
        final q = texto.toLowerCase();
        final filtrada = cache
            .where((v) =>
                (nivel == null || v.riesgo == nivel) &&
                (q.isEmpty || v.codigo.toLowerCase().contains(q) || v.fecha.contains(q)))
            .toList();
        if (mounted) setState(() {
          _lista = filtrada;
          _desdeCache = true;
          _error = null;
        });
      } else if (mounted) {
        setState(() => _error = e.mensaje);
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _alEscribir(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _cargar(sincronizar: false));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        HeaderGradiente(
          titulo: 'Historial',
          subtitulo: '${_lista.length} valoraciones',
          trailing: BotonHeader(
            icono: _mostrarBusqueda ? Icons.close : Icons.search,
            tooltip: 'Buscar',
            onTap: () => setState(() {
              _mostrarBusqueda = !_mostrarBusqueda;
              if (!_mostrarBusqueda && _busqueda.text.isNotEmpty) {
                _busqueda.clear();
                _cargar(sincronizar: false);
              }
            }),
          ),
        ),
        Expanded(
          child: Column(
            children: [
              if (_mostrarBusqueda)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: TextField(
                    controller: _busqueda,
                    autofocus: true,
                    onChanged: _alEscribir,
                    decoration: const InputDecoration(
                        hintText: 'Código o fecha (AAAA-MM-DD)', prefixIcon: Icon(Icons.search)),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: SizedBox(
                  width: double.infinity,
                  child: Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final n in _niveles)
                      ChoiceChip(
                        label: Text(n),
                        selected: _nivel == n,
                        showCheckmark: false,
                        selectedColor: AppColors.primary,
                        backgroundColor: Colors.white,
                        side: BorderSide(
                            color: _nivel == n ? AppColors.primary : AppColors.border, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        labelStyle: TextStyle(
                            color: _nivel == n ? Colors.white : AppColors.muted, fontSize: 13),
                        onSelected: (_) {
                          setState(() => _nivel = n);
                          _cargar(sincronizar: false);
                        },
                      ),
                  ]),
                ),
              ),
              Expanded(child: _contenido()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _contenido() {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ErrorReintentar(mensaje: _error!, onReintentar: _cargar);
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        children: [
          if (_desdeCache)
            const AvisoCaja('Sin conexión: mostrando la última copia guardada en el teléfono',
                icono: Icons.cloud_off),
          if (_pendientes > 0)
            AvisoCaja(
              _conError > 0
                  ? '$_pendientes valoración(es) pendiente(s); $_conError rechazada(s) por el servidor'
                  : '$_pendientes valoración(es) guardada(s) en el teléfono, pendiente(s) de enviar',
              icono: Icons.sync,
              accion: TextButton(
                onPressed: () async {
                  final uid = AuthService.instancia.usuario!.id;
                  if (_conError > 0) {
                    await DbService.instancia.descartarConError(uid);
                  } else {
                    await SyncService.sincronizar(uid);
                  }
                  datosCambiaron.value++;
                },
                child: Text(_conError > 0 ? 'Descartar' : 'Enviar'),
              ),
            ),
          if (_lista.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Text('No se encontraron valoraciones',
                  textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
            ),
          for (final v in _lista)
            ItemValoracion(
              valoracion: v,
              subtitulo: '${fechaCorta(v.fechaHora)} · ${v.edadMeses}m · ${v.hemoglobina} g/dL',
              onTap: () => Navigator.of(context, rootNavigator: true)
                  .push(MaterialPageRoute(builder: (_) => DetalleScreen(valoracion: v))),
            ),
        ],
      ),
    );
  }
}
