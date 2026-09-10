import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'services/esp32_service.dart';
import 'views/native_dashboard_tab.dart';
import 'views/webview_tab.dart';
import 'widgets/ip_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configuración de depuración para InAppWebView en Android
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(kDebugMode);
  }

  final initialIp = await Esp32Service.getSavedIp();
  runApp(Esp32ControlApp(initialIp: initialIp));
}

class Esp32ControlApp extends StatelessWidget {
  final String initialIp;

  const Esp32ControlApp({super.key, required this.initialIp});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ESP32 Domótica',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.light,
        appBarTheme: const AppBarTheme(
          elevation: 1,
          centerTitle: false,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      home: HomeScreen(initialIp: initialIp),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final String initialIp;

  const HomeScreen({super.key, required this.initialIp});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late String _currentIp;

  final GlobalKey<WebViewTabState> _webViewKey = GlobalKey<WebViewTabState>();
  final GlobalKey<NativeDashboardTabState> _nativeTabKey =
      GlobalKey<NativeDashboardTabState>();

  @override
  void initState() {
    super.initState();
    _currentIp = widget.initialIp;
  }

  void _onRefreshPressed() {
    if (_currentIndex == 0) {
      _webViewKey.currentState?.reload();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recargando WebView del ESP32...'),
          duration: Duration(seconds: 1),
        ),
      );
    } else {
      _nativeTabKey.currentState?.refreshData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Actualizando datos de sensores...'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _showIpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => IpDialog(
        currentIp: _currentIp,
        onIpSaved: (newIp) async {
          await Esp32Service.saveIp(newIp);
          setState(() {
            _currentIp = newIp;
          });
          _webViewKey.currentState?.loadNewIp(newIp);
          _nativeTabKey.currentState?.refreshData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('IP actualizada a $newIp'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ESP32 Domótica',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'IP: $_currentIp',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          // Botón para configurar la IP
          IconButton(
            tooltip: 'Configurar IP del ESP32',
            icon: const Icon(Icons.settings_ethernet),
            onPressed: _showIpDialog,
          ),
          // Botón obligatorio de Recarga (Refresh) en la AppBar
          IconButton(
            tooltip: 'Recargar Interfaz',
            icon: const Icon(Icons.refresh),
            onPressed: _onRefreshPressed,
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // Pestaña 1: WebView completa conectada al ESP32
          WebViewTab(
            key: _webViewKey,
            ipAddress: _currentIp,
          ),

          // Pestaña 2: Panel Nativo de Control para endpoints REST
          NativeDashboardTab(
            key: _nativeTabKey,
            ipAddress: _currentIp,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) {
          setState(() {
            _currentIndex = idx;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.web),
            selectedIcon: Icon(Icons.web_stories),
            label: 'Web ESP32',
          ),
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Panel Nativo',
          ),
        ],
      ),
    );
  }
}
