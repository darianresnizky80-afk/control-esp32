/*
  Firmware de Ejemplo para Servidor Web Domótico ESP32
  Compatible con la Aplicación Flutter / Android
  
  Rutas implementadas:
  - GET /          -> Sirve la interfaz web HTML/JS/CSS embebida
  - GET /datos     -> Retorna JSON con telemetría (gas, luxes, posición motor, brillo, etc.)
  - GET /girar     -> Control del motor a pasos (?dir=X&vueltas=Y&accion=Z)
  - GET /setBrillo -> Ajusta dimmer CA (?val=X)
  - GET /setSetpoint -> Ajusta consigna luxes (?val=X)
  - GET /toggleModo  -> Alterna entre modo Auto y Manual
  - GET /setLimite, /resetPos, /setPosMax -> Calibración de motor
*/

#include <WiFi.h>
#include <WebServer.h>

const char* ssid = "TU_RED_WIFI";
const char* password = "TU_CONTRASEÑA_WIFI";

WebServer server(80);

// Variables de estado del sistema
float nivelGas = 145.2;
float nivelLuxes = 420.0;
float setpointLuxes = 500.0;
int posicionMotor = 1024;
int maxPosicionMotor = 4096;
int brilloDimmer = 75;
bool modoAutomatico = true;

// Interfaz Web HTML5/JS servida directamente por el ESP32
const char INDEX_HTML[] PROGMEM = R"rawliteral(
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Panel ESP32</title>
  <style>
    body { font-family: sans-serif; margin: 0; padding: 20px; background: #0f172a; color: #f8fafc; }
    .card { background: #1e293b; padding: 18px; border-radius: 12px; margin-bottom: 16px; box-shadow: 0 4px 6px rgba(0,0,0,0.3); }
    h2 { margin-top: 0; color: #38bdf8; font-size: 1.2rem; }
    .val { font-size: 1.8rem; font-weight: bold; color: #4ade80; }
    button { background: #3b82f6; border: none; color: white; padding: 10px 18px; border-radius: 8px; font-weight: bold; cursor: pointer; }
    button:active { background: #1d4ed8; }
    input[type=range] { width: 100%; }
    .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
  </style>
</head>
<body>
  <div class="card">
    <h2>📡 Telemetría ESP32</h2>
    <div class="grid">
      <div><small>Gas MQ:</small><div class="val" id="gasVal">--</div></div>
      <div><small>Luz Ambiente:</small><div class="val" id="luxVal">--</div></div>
    </div>
  </div>

  <div class="card">
    <h2>💡 Control de Brillo CA</h2>
    <input type="range" min="0" max="100" id="brilloRange" onchange="cambiarBrillo(this.value)">
    <p>Nivel: <span id="brilloLabel">0%</span></p>
  </div>

  <div class="card">
    <h2>⚙️ Motor a Pasos</h2>
    <div style="display:flex; gap:8px;">
      <button onclick="girar(1, 1, 'abrir')">Abrir (1 vuelta)</button>
      <button onclick="girar(0, 1, 'cerrar')">Cerrar (1 vuelta)</button>
    </div>
    <p>Posición: <span id="posVal">0</span></p>
  </div>

  <script>
    function actualizarDatos() {
      fetch('/datos')
        .then(r => r.json())
        .then(data => {
          document.getElementById('gasVal').innerText = data.gas + ' PPM';
          document.getElementById('luxVal').innerText = data.luxes + ' Lux';
          document.getElementById('posVal').innerText = data.motorPos;
          document.getElementById('brilloLabel').innerText = data.brillo + '%';
        })
        .catch(e => console.error("Error AJAX /datos:", e));
    }

    function cambiarBrillo(val) {
      document.getElementById('brilloLabel').innerText = val + '%';
      fetch('/setBrillo?val=' + val);
    }

    function girar(dir, vueltas, accion) {
      fetch('/girar?dir=' + dir + '&vueltas=' + vueltas + '&accion=' + accion);
    }

    setInterval(actualizarDatos, 2000);
    window.onload = actualizarDatos;
  </script>
</body>
</html>
)rawliteral";

void agregarCabecerasCORS() {
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.sendHeader("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
  server.sendHeader("Access-Control-Allow-Headers", "*");
}

void handleRoot() {
  agregarCabecerasCORS();
  server.send_P(200, "text/html", INDEX_HTML);
}

void handleDatos() {
  agregarCabecerasCORS();
  // Simular ligeras variaciones
  nivelGas += (random(-5, 6) * 0.1);
  nivelLuxes += (random(-10, 11) * 0.5);

  String json = "{";
  json += "\"gas\":" + String(nivelGas, 1) + ",";
  json += "\"luxes\":" + String(nivelLuxes, 1) + ",";
  json += "\"setpoint\":" + String(setpointLuxes, 1) + ",";
  json += "\"motorPos\":" + String(posicionMotor) + ",";
  json += "\"motorMax\":" + String(maxPosicionMotor) + ",";
  json += "\"brillo\":" + String(brilloDimmer) + ",";
  json += "\"modoAuto\":" + String(modoAutomatico ? "true" : "false");
  json += "}";

  server.send(200, "application/json", json);
}

void handleGirar() {
  agregarCabecerasCORS();
  String dir = server.arg("dir");
  float vueltas = server.arg("vueltas").toFloat();
  String accion = server.arg("accion");

  if (vueltas <= 0) vueltas = 1.0;
  int pasos = (int)(vueltas * 512); // Pasos para motor 28BYJ-48
  if (dir == "1") {
    posicionMotor += pasos;
  } else {
    posicionMotor -= pasos;
  }

  server.send(200, "text/plain", "Motor girando: dir=" + dir + ", vueltas=" + String(vueltas) + ", accion=" + accion);
}

void handleSetBrillo() {
  agregarCabecerasCORS();
  if (server.hasArg("val")) {
    brilloDimmer = server.arg("val").toInt();
    server.send(200, "text/plain", "Brillo ajustado a " + String(brilloDimmer));
  } else {
    server.send(400, "text/plain", "Falta parametro val");
  }
}

void handleSetSetpoint() {
  agregarCabecerasCORS();
  if (server.hasArg("val")) {
    setpointLuxes = server.arg("val").toFloat();
    server.send(200, "text/plain", "Setpoint ajustado a " + String(setpointLuxes));
  } else {
    server.send(400, "text/plain", "Falta parametro val");
  }
}

void handleToggleModo() {
  agregarCabecerasCORS();
  modoAutomatico = !modoAutomatico;
  server.send(200, "text/plain", modoAutomatico ? "Modo Auto" : "Modo Manual");
}

void handleSetLimite() {
  agregarCabecerasCORS();
  server.send(200, "text/plain", "Limite fijado en posicion actual");
}

void handleResetPos() {
  agregarCabecerasCORS();
  posicionMotor = 0;
  server.send(200, "text/plain", "Posicion reiniciada a 0");
}

void handleSetPosMax() {
  agregarCabecerasCORS();
  maxPosicionMotor = posicionMotor;
  server.send(200, "text/plain", "Posicion maxima fijada en " + String(maxPosicionMotor));
}

void setup() {
  Serial.begin(115200);
  WiFi.begin(ssid, password);
  Serial.print("Conectando a WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nConectado a WiFi!");
  Serial.print("Direccion IP del ESP32: ");
  Serial.println(WiFi.localIP());

  // Registrar Rutas HTTP
  server.on("/", handleRoot);
  server.on("/datos", handleDatos);
  server.on("/girar", handleGirar);
  server.on("/setBrillo", handleSetBrillo);
  server.on("/setSetpoint", handleSetSetpoint);
  server.on("/toggleModo", handleToggleModo);
  server.on("/setLimite", handleSetLimite);
  server.on("/resetPos", handleResetPos);
  server.on("/setPosMax", handleSetPosMax);

  server.begin();
  Serial.println("Servidor HTTP iniciado correctamente en puerto 80");
}

void loop() {
  server.handleClient();
}
