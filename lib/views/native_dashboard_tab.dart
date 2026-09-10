import 'dart:async';
import 'package:flutter/material.dart';
import '../models/esp32_data.dart';
import '../services/esp32_service.dart';

class NativeDashboardTab extends StatefulWidget {
  final String ipAddress;

  const NativeDashboardTab({
    super.key,
    required this.ipAddress,
  });

  @override
  State<NativeDashboardTab> createState() => NativeDashboardTabState();
}

class NativeDashboardTabState extends State<NativeDashboardTab> {
  Esp32Data? _data;
  bool _loading = false;
  bool _autoPoll = true;
  Timer? _pollTimer;
  String _lastLog = 'Listo para enviar órdenes.';

  // Parámetros para girar motor
  String _motorDir = '1'; // 1 = horario, 0 = antihorario
  double _motorVueltas = 1.0;
  String _motorAccion = 'abrir';

  // Parámetros de brillo y setpoint
  double _currentBrillo = 0;
  double _currentSetpoint = 500;
  bool _modoAuto = true;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void didUpdateWidget(covariant NativeDashboardTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ipAddress != widget.ipAddress) {
      refreshData();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    refreshData();
    if (_autoPoll) {
      _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
        if (_autoPoll && mounted) {
          _silentRefresh();
        }
      });
    }
  }

  Future<void> refreshData() async {
    setState(() => _loading = true);
    try {
      final data = await Esp32Service.fetchDatos(widget.ipAddress);
      if (!mounted) return;
      setState(() {
        _data = data;
        _currentBrillo = data.brillo.toDouble();
        _currentSetpoint = data.setpoint;
        _modoAuto = data.modoAuto;
        _loading = false;
        _lastLog = 'Lectura exitosa de /datos';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _lastLog = 'Error conectando con /datos: $e';
      });
    }
  }

  Future<void> _silentRefresh() async {
    try {
      final data = await Esp32Service.fetchDatos(widget.ipAddress);
      if (!mounted) return;
      setState(() {
        _data = data;
      });
    } catch (_) {}
  }

  Future<void> _sendCommand(String name, Future<String> action) async {
    setState(() => _lastLog = 'Enviando $name...');
    try {
      final resp = await action;
      if (!mounted) return;
      setState(() => _lastLog = '[$name OK]: $resp');
      _showSnackbar('Comando ejecutado con éxito');
      refreshData();
    } catch (e) {
      if (!mounted) return;
      setState(() => _lastLog = '[$name ERROR]: $e');
      _showSnackbar('Fallo al ejecutar comando: $e', isError: true);
    }
  }

  void _showSnackbar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : Colors.teal,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: refreshData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Barra de estado superior con switch de polling
            _buildTopStatusBar(theme),
            const SizedBox(height: 16),

            // Tarjetas de Lecturas de Sensores
            _buildSensorsCard(theme),
            const SizedBox(height: 16),

            // Tarjeta de Control del Dimmer CA y Modo
            _buildDimmerAndModeCard(theme),
            const SizedBox(height: 16),

            // Tarjeta de Consigna de Luxes (Setpoint)
            _buildSetpointCard(theme),
            const SizedBox(height: 16),

            // Tarjeta de Control de Motor a Pasos
            _buildStepperMotorCard(theme),
            const SizedBox(height: 16),

            // Consola de Registro en vivo
            _buildLogConsole(theme),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTopStatusBar(ThemeData theme) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  _data != null ? Icons.check_circle : Icons.warning_amber,
                  color: _data != null ? Colors.green : Colors.amber,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _data != null ? 'Conectado a /datos' : 'Desconectado',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ],
            ),
            Row(
              children: [
                const Text('Auto-Refresco', style: TextStyle(fontSize: 12)),
                Switch(
                  value: _autoPoll,
                  onChanged: (val) {
                    setState(() => _autoPoll = val);
                    _startPolling();
                  },
                ),
                IconButton(
                  icon: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 20),
                  onPressed: _loading ? null : refreshData,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorsCard(ThemeData theme) {
    final gasVal = _data?.gas ?? 0.0;
    final isGasDangerous = gasVal > 400; // Umbral estimado

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.sensors, color: Colors.indigo),
                SizedBox(width: 8),
                Text(
                  'Telemetría en Tiempo Real',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                // Sensor de Gas
                Expanded(
                  child: _buildMetricTile(
                    title: 'Sensor de Gas',
                    value: '${gasVal.toStringAsFixed(1)} PPM',
                    icon: Icons.air,
                    color: isGasDangerous ? Colors.red : Colors.teal,
                    subtitle: isGasDangerous ? '¡Alerta Gas!' : 'Nivel Seguro',
                  ),
                ),
                const SizedBox(width: 12),
                // Sensor de Luxes
                Expanded(
                  child: _buildMetricTile(
                    title: 'Luz Ambiente',
                    value: '${(_data?.luxes ?? 0.0).toStringAsFixed(1)} Lux',
                    icon: Icons.wb_sunny_outlined,
                    color: Colors.amber.shade800,
                    subtitle: 'Lectura LDR / I2C',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Posición Motor
                Expanded(
                  child: _buildMetricTile(
                    title: 'Posición Motor',
                    value: '${_data?.motorPos ?? 0} / ${_data?.motorMax ?? 4096}',
                    icon: Icons.rotate_right,
                    color: Colors.blueAccent,
                    subtitle: 'Pasos actuales',
                  ),
                ),
                const SizedBox(width: 12),
                // Modo Actual
                Expanded(
                  child: _buildMetricTile(
                    title: 'Modo Sistema',
                    value: (_data?.modoAuto ?? true) ? 'AUTOMÁTICO' : 'MANUAL',
                    icon: Icons.settings_suggest,
                    color: (_data?.modoAuto ?? true) ? Colors.deepPurple : Colors.orange,
                    subtitle: 'Control domótico',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildDimmerAndModeCard(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: Colors.orangeAccent),
                    SizedBox(width: 8),
                    Text(
                      'Dimmer de Iluminación CA',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Text(
                  '${_currentBrillo.toInt()}%',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Ajuste del triac / dimmer (/setBrillo?val=X)',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            Slider(
              value: _currentBrillo.clamp(0, 100),
              min: 0,
              max: 100,
              divisions: 20,
              label: '${_currentBrillo.toInt()}%',
              onChanged: (val) {
                setState(() => _currentBrillo = val);
              },
              onChangeEnd: (val) {
                _sendCommand(
                  'setBrillo (${val.toInt()}%)',
                  Esp32Service.setBrillo(widget.ipAddress, val.toInt()),
                );
              },
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Alternar Modo Auto / Manual',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    Text(
                      'Ruta: GET /toggleModo (Actual: ${_modoAuto ? 'Automático' : 'Manual'})',
                      style: const TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ],
                ),
                FilledButton.tonal(
                  onPressed: () {
                    _sendCommand(
                      'toggleModo',
                      Esp32Service.toggleModo(widget.ipAddress),
                    );
                  },
                  child: const Text('Cambiar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetpointCard(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.tune, color: Colors.deepPurple),
                    SizedBox(width: 8),
                    Text(
                      'Consigna de Luxes (Setpoint)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Text(
                  '${_currentSetpoint.toInt()} Lux',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Ruta: GET /setSetpoint?val=X (Nivel de luz deseado para control automático)',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            Slider(
              value: _currentSetpoint.clamp(0, 2000),
              min: 0,
              max: 2000,
              divisions: 40,
              label: '${_currentSetpoint.toInt()} Lux',
              onChanged: (val) {
                setState(() => _currentSetpoint = val);
              },
              onChangeEnd: (val) {
                _sendCommand(
                  'setSetpoint (${val.toInt()} Lux)',
                  Esp32Service.setSetpoint(widget.ipAddress, val.toInt()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepperMotorCard(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.engineering, color: Colors.blueAccent),
                SizedBox(width: 8),
                Text(
                  'Control del Motor a Pasos',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Ruta: GET /girar?dir=X&vueltas=Y&accion=Z',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 16),

            // Selectores de Dirección y Acción
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _motorDir,
                    decoration: const InputDecoration(
                      labelText: 'Dirección (dir)',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: '1', child: Text('Horario (1)')),
                      DropdownMenuItem(value: '0', child: Text('Antihorario (0)')),
                    ],
                    onChanged: (v) => setState(() => _motorDir = v ?? '1'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _motorAccion,
                    decoration: const InputDecoration(
                      labelText: 'Acción (accion)',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'abrir', child: Text('Abrir')),
                      DropdownMenuItem(value: 'cerrar', child: Text('Cerrar')),
                      DropdownMenuItem(value: 'paso', child: Text('Paso libre')),
                    ],
                    onChanged: (v) => setState(() => _motorAccion = v ?? 'abrir'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Selector de vueltas
            Row(
              children: [
                Text(
                  'Vueltas: ${_motorVueltas.toStringAsFixed(1)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Expanded(
                  child: Slider(
                    value: _motorVueltas,
                    min: 0.5,
                    max: 10.0,
                    divisions: 19,
                    label: '${_motorVueltas.toStringAsFixed(1)}',
                    onChanged: (val) => setState(() => _motorVueltas = val),
                  ),
                ),
              ],
            ),

            // Botón de Ejecutar Giro
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('Girar Motor'),
                onPressed: () {
                  _sendCommand(
                    'girar(dir=$_motorDir, vueltas=$_motorVueltas, accion=$_motorAccion)',
                    Esp32Service.girarMotor(
                      ip: widget.ipAddress,
                      dir: _motorDir,
                      vueltas: _motorVueltas,
                      accion: _motorAccion,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'Calibración y Límites de Fin de Carrera:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.exposure_zero, size: 16),
                  label: const Text('Reset Pos (/resetPos)'),
                  onPressed: () {
                    _sendCommand('resetPos', Esp32Service.resetPos(widget.ipAddress));
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.vertical_align_bottom, size: 16),
                  label: const Text('Fijar Límite (/setLimite)'),
                  onPressed: () {
                    _sendCommand('setLimite', Esp32Service.setLimite(widget.ipAddress));
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.vertical_align_top, size: 16),
                  label: const Text('Fijar Máximo (/setPosMax)'),
                  onPressed: () {
                    _sendCommand('setPosMax', Esp32Service.setPosMax(widget.ipAddress));
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogConsole(ThemeData theme) {
    return Card(
      elevation: 0,
      color: Colors.black87,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.terminal, color: Colors.greenAccent, size: 16),
                SizedBox(width: 6),
                Text(
                  'Registro de Comandos HTTP',
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _lastLog,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
