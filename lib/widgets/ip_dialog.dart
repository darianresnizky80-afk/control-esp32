import 'package:flutter/material.dart';
import '../services/esp32_service.dart';

class IpDialog extends StatefulWidget {
  final String currentIp;
  final Function(String newIp) onIpSaved;

  const IpDialog({
    super.key,
    required this.currentIp,
    required this.onIpSaved,
  });

  @override
  State<IpDialog> createState() => _IpDialogState();
}

class _IpDialogState extends State<IpDialog> {
  late TextEditingController _controller;
  bool _testing = false;
  bool? _testResult;
  String? _testMessage;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentIp);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _testPing() async {
    setState(() {
      _testing = true;
      _testResult = null;
      _testMessage = null;
    });

    final ip = _controller.text.trim();
    final ok = await Esp32Service.testConnection(ip);

    if (!mounted) return;
    setState(() {
      _testing = false;
      _testResult = ok;
      _testMessage = ok
          ? '¡Conexión exitosa con el ESP32!'
          : 'No se pudo conectar. Verifica que estés en la misma red Wi-Fi.';
    });
  }

  void _save() {
    final ip = _controller.text.trim();
    if (ip.isNotEmpty) {
      widget.onIpSaved(ip);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.router, color: Colors.blueAccent),
          SizedBox(width: 8),
          Text('Dirección IP del ESP32'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Introduce la dirección IP local del microcontrolador en la red:',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                hintText: 'ej. 192.168.1.50',
                prefixIcon: const Icon(Icons.wifi),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _controller.clear(),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: OutlinedButton.icon(
                onPressed: _testing ? null : _testPing,
                icon: _testing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.network_check),
                label: Text(_testing ? 'Comprobando...' : 'Probar Conexión'),
              ),
            ),
            if (_testMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _testResult == true
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _testResult == true ? Colors.green : Colors.red,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _testResult == true
                          ? Icons.check_circle
                          : Icons.error_outline,
                      color: _testResult == true ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _testMessage!,
                        style: TextStyle(
                          fontSize: 12,
                          color: _testResult == true
                              ? Colors.green.shade900
                              : Colors.red.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Guardar y Conectar'),
        ),
      ],
    );
  }
}
