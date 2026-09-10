# ESP32 Domótica - Panel de Control (Flutter & Android Native)

Aplicación móvil Android para monitoreo y control domótico de un ESP32 mediante WebView embebido de alto rendimiento y panel de mandos nativo REST.

---

## 🌟 Características Principales

1. **WebView Embebida Optimizada:**
   - Permite tráfico no cifrado local (`android:usesCleartextTraffic="true"`).
   - Opciones `allowsInsecureHTTPLoads: true` y `mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW` activadas.
   - Ejecución completa de JavaScript y almacenamiento local de DOM (`domStorageEnabled: true`).
   - Pantalla de contingencia y diagnóstico si el ESP32 no responde o pierde conexión Wi-Fi.

2. **Panel de Mandos Nativo Alternativo:**
   - Comunicación directa vía peticiones HTTP GET a la API REST del microcontrolador.
   - Telemetría en vivo: Sensor de Gas, Sensor de Luxes ambiente, Posición de pasos del motor, Estado del sistema.
   - Control de Dimmer CA con Slider en tiempo real (`/setBrillo?val=X`).
   - Ajuste de consigna de luz ambiente (`/setSetpoint?val=X`).
   - Giro del motor a pasos por vueltas y dirección horaria/antihoraria (`/girar?dir=X&vueltas=Y&accion=Z`).
   - Calibración de motor: Límite, Puesta a Cero y Posición Máxima (`/setLimite`, `/resetPos`, `/setPosMax`).
   - Alternancia de Modo Automático y Manual (`/toggleModo`).

3. **Configuración Dinámica de IP:**
   - Botón en la barra superior para cambiar la dirección IP del ESP32 en caliente sin recompilar la app.
   - Persistencia de la IP en almacenamiento local (`SharedPreferences`).
   - Botón de test rápido de conectividad (Ping).

4. **Botón de Recarga (Refresh):**
   - Integrado en el `AppBar` superior para forzar la recarga tanto del WebView como del panel de sensores en cualquier momento.

---

## 📁 Estructura del Proyecto

```text
esp32_control_panel/
├── android/
│   ├── app/
│   │   ├── src/main/
│   │   │   ├── AndroidManifest.xml          # usesCleartextTraffic="true" e INTERNET
│   │   │   └── res/xml/network_security_config.xml # Tráfico local permitido
│   │   └── build.gradle                     # minSdk 21, compileSdk 34
│   ├── build.gradle
│   └── settings.gradle
├── lib/
│   ├── models/
│   │   └── esp32_data.dart                  # Modelo para /datos
│   ├── services/
│   │   └── esp32_service.dart               # Cliente HTTP y SharedPreferences
│   ├── views/
│   │   ├── webview_tab.dart                 # InAppWebView con bypass CORS / Cleartext
│   │   └── native_dashboard_tab.dart        # Dashboard nativo Material 3
│   ├── widgets/
│   │   └── ip_dialog.dart                   # Diálogo para cambio y test de IP
│   └── main.dart                            # Entrada de la aplicación
├── esp32_firmware_sample/
│   └── esp32_firmware_sample.ino            # Sketch Arduino con servidor HTTP y CORS
├── .github/workflows/
│   └── build_apk.yml                        # Compilación automática en GitHub Actions
├── build_apk.ps1                            # Script PowerShell de compilación local
└── pubspec.yaml                             # Dependencias del proyecto
```

---

## 🚀 Compilación del APK

### Opción 1: Compilación Local con Flutter SDK
1. Abre una terminal de PowerShell en esta carpeta.
2. Asegúrate de tener instalado Flutter SDK y Java JDK 17.
3. Ejecuta el script:
   ```powershell
   .\build_apk.ps1
   ```
   O manualmente:
   ```bash
   flutter pub get
   flutter build apk --release
   ```
4. El archivo generado se encontrará en:
   `build/app/outputs/flutter-apk/app-release.apk`

### Opción 2: Compilación Automática en la Nube (GitHub Actions)
1. Sube este proyecto a un repositorio de GitHub.
2. La acción `.github/workflows/build_apk.yml` compilará automáticamente el `.apk` en los servidores de GitHub y lo dejará disponible para descargar en la pestaña **Actions > Artifacts**.
