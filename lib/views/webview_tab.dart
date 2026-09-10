import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../services/esp32_service.dart';

class WebViewTab extends StatefulWidget {
  final String ipAddress;
  final Function(InAppWebViewController controller)? onControllerReady;

  const WebViewTab({
    super.key,
    required this.ipAddress,
    this.onControllerReady,
  });

  @override
  State<WebViewTab> createState() => WebViewTabState();
}

class WebViewTabState extends State<WebViewTab> {
  InAppWebViewController? webViewController;
  PullToRefreshController? pullToRefreshController;
  double progress = 0;
  bool hasError = false;
  String errorMessage = '';

  late InAppWebViewSettings settings;

  @override
  void initState() {
    super.initState();

    // Configuración técnica estricta requerida para comunicación HTTP y CORS con ESP32
    settings = InAppWebViewSettings(
      allowsInsecureHTTPLoads: true,
      mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
      javaScriptEnabled: true,
      domStorageEnabled: true,
      useShouldOverrideUrlLoading: false,
      mediaPlaybackRequiresUserGesture: false,
      supportZoom: true,
      builtInZoomControls: true,
      displayZoomControls: false,
      allowFileAccessFromFileURLs: true,
      allowUniversalAccessFromFileURLs: true,
      cacheEnabled: false,
      clearCache: true,
      useHybridComposition: true,
    );

    pullToRefreshController = kIsWeb
        ? null
        : PullToRefreshController(
            settings: PullToRefreshSettings(
              color: Colors.blueAccent,
            ),
            onRefresh: () async {
              if (defaultTargetPlatform == TargetPlatform.android) {
                webViewController?.reload();
              } else if (defaultTargetPlatform == TargetPlatform.iOS) {
                webViewController?.loadUrl(
                  urlRequest: URLRequest(url: await webViewController?.getUrl()),
                );
              }
            },
          );
  }

  /// Recarga la página actual del ESP32
  Future<void> reload() async {
    setState(() {
      hasError = false;
      errorMessage = '';
    });
    if (webViewController != null) {
      await webViewController!.reload();
    }
  }

  /// Carga una nueva URL base
  Future<void> loadNewIp(String ip) async {
    setState(() {
      hasError = false;
      errorMessage = '';
    });
    final formattedUrl = WebUri(Esp32Service.formatBaseUrl(ip));
    if (webViewController != null) {
      await webViewController!.loadUrl(
        urlRequest: URLRequest(url: formattedUrl),
      );
    }
  }

  @override
  void didUpdateWidget(covariant WebViewTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ipAddress != widget.ipAddress) {
      loadNewIp(widget.ipAddress);
    }
  }

  @override
  Widget build(BuildContext context) {
    final targetUrl = WebUri(Esp32Service.formatBaseUrl(widget.ipAddress));

    return Stack(
      children: [
        if (!hasError)
          InAppWebView(
            initialUrlRequest: URLRequest(url: targetUrl),
            initialSettings: settings,
            pullToRefreshController: pullToRefreshController,
            onWebViewCreated: (controller) {
              webViewController = controller;
              widget.onControllerReady?.call(controller);
            },
            onLoadStart: (controller, url) {
              setState(() {
                progress = 0;
                hasError = false;
              });
            },
            onProgressChanged: (controller, newProgress) {
              if (newProgress == 100) {
                pullToRefreshController?.endRefreshing();
              }
              setState(() {
                progress = newProgress / 100;
              });
            },
            onLoadStop: (controller, url) async {
              pullToRefreshController?.endRefreshing();
              setState(() {
                progress = 1.0;
              });
            },
            onReceivedError: (controller, request, error) {
              pullToRefreshController?.endRefreshing();
              setState(() {
                hasError = true;
                errorMessage = error.description;
              });
            },
            onReceivedHttpError: (controller, request, errorResponse) {
              pullToRefreshController?.endRefreshing();
              // Solo mostrar error fatal si es la página principal
              if (request.url.toString() == targetUrl.toString() ||
                  request.url.toString() == '${targetUrl.toString()}/') {
                setState(() {
                  hasError = true;
                  errorMessage =
                      'Error HTTP ${errorResponse.statusCode}: ${errorResponse.reasonPhrase}';
                });
              }
            },
            onConsoleMessage: (controller, consoleMessage) {
              if (kDebugMode) {
                print("[ESP32 WebView Console] ${consoleMessage.message}");
              }
            },
          ),

        // Barra de progreso superior mientras carga
        if (progress < 1.0 && !hasError)
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.transparent,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.amberAccent),
            minHeight: 3,
          ),

        // Pantalla de error amigable cuando el ESP32 no responde
        if (hasError)
          _buildErrorState(context),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 72,
              color: Colors.deepOrangeAccent,
            ),
            const SizedBox(height: 16),
            const Text(
              'No se pudo conectar con el ESP32',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Dirección intentada: ${Esp32Service.formatBaseUrl(widget.ipAddress)}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            if (errorMessage.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Detalle: $errorMessage',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Colors.redAccent),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blueGrey.shade200),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💡 Guía de Solución de Problemas:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '1. Asegúrate de que tu smartphone esté conectado a la misma red Wi-Fi (2.4 GHz).\n'
                    '2. Verifica en el Monitor Serie de Arduino la IP que obtuvo el ESP32.\n'
                    '3. Revisa que el ESP32 tenga alimentada su fuente de poder y esté encendido.',
                    style: TextStyle(fontSize: 11, color: Colors.black87),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: reload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
