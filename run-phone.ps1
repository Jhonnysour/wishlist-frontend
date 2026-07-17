<#
.SYNOPSIS
  Lanza la app Wishlist en un telefono Android conectado por USB, en un solo paso.

.DESCRIPTION
  - Mapea el puerto 8000 del telefono al de la PC (adb reverse), para que el telefono
    alcance el backend en localhost:8000 sin importar WiFi/VPN.
  - Corre `flutter run` con la base URL apuntando a localhost.

  El backend debe estar corriendo aparte (uvicorn main:app en su propio repo).

.EXAMPLE
  ./run-phone.ps1
  ./run-phone.ps1 -d RZCY807GRRZ    # argumentos extra se reenvian a flutter run
#>

$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot

# --- Resolver adb -------------------------------------------------------------
$adb = Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"
if (-not (Test-Path $adb)) {
    Write-Host "No se encontro adb en: $adb" -ForegroundColor Red
    Write-Host "Instala las 'Android SDK platform-tools' (vienen con Android Studio)."
    exit 1
}

# --- Verificar que haya un telefono conectado ---------------------------------
$attached = & $adb devices | Select-String -Pattern "\tdevice$"
if (-not $attached) {
    Write-Host "No hay ningun telefono conectado por USB con depuracion activada." -ForegroundColor Red
    Write-Host "Conectalo, acepta el dialogo 'Permitir depuracion USB' y vuelve a intentar."
    exit 1
}

# --- Aviso no bloqueante si el backend no responde ----------------------------
try {
    Invoke-WebRequest -Uri "http://localhost:8000/docs" -TimeoutSec 2 -UseBasicParsing | Out-Null
} catch {
    Write-Host "Aviso: nada responde en http://localhost:8000 - esta corriendo el backend?" -ForegroundColor Yellow
    Write-Host "        (En su repo: uvicorn main:app). Continuo de todos modos."
    Write-Host ""
}

# --- Mapear el puerto y lanzar ------------------------------------------------
Write-Host "Mapeando puerto 8000 (adb reverse)..." -ForegroundColor Cyan
& $adb reverse tcp:8000 tcp:8000 | Out-Null

Write-Host "Lanzando la app en el telefono..." -ForegroundColor Cyan
Write-Host ""
flutter run --dart-define=API_BASE_URL=http://localhost:8000 @args
