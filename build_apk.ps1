# Script de Compilación Automática para el APK de Flutter
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "   Compilador APK - Panel Domótico ESP32" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# 1. Comprobar si Flutter está en el PATH
$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue

if (-not $flutterCmd) {
    Write-Host "[!] Flutter no está instalado o no se encuentra en el PATH del sistema." -ForegroundColor Yellow
    Write-Host "    Para compilar localmente este proyecto:" -ForegroundColor Yellow
    Write-Host "    1. Descarga Flutter SDK de: https://docs.flutter.dev/get-started/install/windows/mobile" -ForegroundColor White
    Write-Host "    2. Descomprime en C:\src\flutter y añade C:\src\flutter\bin a tus Variables de Entorno (PATH)." -ForegroundColor White
    Write-Host "    3. Vuelve a ejecutar este script." -ForegroundColor White
    Write-Host ""
    Write-Host "    O bien, sube este proyecto a GitHub: ¡el workflow en .github/workflows/build_apk.yml compila el APK en la nube automáticamente!" -ForegroundColor Green
    Exit 1
}

Write-Host "[+] Flutter detectado: $($flutterCmd.Source)" -ForegroundColor Green

# 2. Descargar dependencias
Write-Host "[*] Obteniendo dependencias (flutter pub get)..." -ForegroundColor Cyan
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "[X] Error al obtener dependencias." -ForegroundColor Red
    Exit $LASTEXITCODE
}

# 3. Compilar APK Release
Write-Host "[*] Compilando APK Release (flutter build apk --release)..." -ForegroundColor Cyan
flutter build apk --release

if ($LASTEXITCODE -eq 0) {
    $apkPath = "build\app\outputs\flutter-apk\app-release.apk"
    if (Test-Path $apkPath) {
        Copy-Item -Path $apkPath -Destination "ESP32_Domotica.apk" -Force
        Write-Host "==================================================" -ForegroundColor Green
        Write-Host " [V] ¡APK COMPILADO CON ÉXITO!" -ForegroundColor Green
        Write-Host " Archivo listo en: $(Resolve-Path 'ESP32_Domotica.apk')" -ForegroundColor Yellow
        Write-Host "==================================================" -ForegroundColor Green
    }
} else {
    Write-Host "[X] Falló la compilación del APK." -ForegroundColor Red
    Exit $LASTEXITCODE
}
