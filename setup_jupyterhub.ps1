#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Script para desplegar JupyterHub con Docker en Windows.
.DESCRIPTION
    Este script automatiza la instalación de las dependencias necesarias (como Docker Desktop y Node.js usando Chocolatey), crea los archivos de configuración necesarios y levanta JupyterHub usando Docker Compose.
.NOTES
    Autor: Gabriel Álvarez
    Tutor: Alejandro Pujol
#>

# Parte 1: instalación de dependencias y configuración inicial
Write-Host "Instalando dependencias..." -ForegroundColor Yellow

# Verifica si Chocolatey está instalado
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
  Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
} 

# Instalar Docker Desktop si no está instalado
$existeDocker = Get-Command docker-compose -ErrorAction SilentlyContinue
if (-not $existeDocker) {
  choco install docker-desktop -y --force
  Start-Sleep -Seconds 15 # Tiempo de espera luego de la instalación
  # Lo agrega a las variables de entorno
  $dockerPath = "$env:ProgramFiles\Docker\Docker\resources\bin"
  if (Test-Path $dockerPath -PathType Container) {
    if (-not ($env:Path -split ';' -contains $dockerPath)) {
      $env:Path += ";$dockerPath"
      Write-Host "Path actualizado con la ruta de Docker: $dockerPath"
      $env:Path = $env:Path
    }
  }
}

# Instala magick para cambiar el .png a .ico
$magickInstalado = Get-Command magick -ErrorAction SilentlyContinue
if (-not $magickInstalado) {
  choco install imagemagick.app -y --force
}

# Instalar Node si no está instalado
$nodeYaInstalado = Get-Command node -ErrorAction SilentlyContinue
if (-not $nodeYaInstalado) {
  choco install nodejs-lts -y --force
}

Read-Host "Presiona Enter cuando tengas Docker abierto de fondo para continuar..."

# Parte 2: Crear los archivos para modificar el front end
Write-Host "Modificando la interfaz..." -ForegroundColor Yellow

# Crear directorio y moverse a él
$carpetaDelProyecto = "unahurhubData"
New-Item -Path $carpetaDelProyecto -ItemType Directory -Force | Out-Null
Set-Location -Path $carpetaDelProyecto

# Descarga las imágenes necesarias
$urlImagenFavicon = "https://pbs.twimg.com/profile_images/1630292819842674692/6qjxhY86.jpg"
$logoFaviconOriginal = "logo.png"
$logoFavicon = "favicon.ico"

$urlImagenModoOscuro = "https://raw.githubusercontent.com/gab-alvarez/unahurhub/refs/heads/main/UNaHurHub/logoModoOscuro.png"
$logoModoOscuro = "logoModoOscuro.png"

$urlImagenModoClaro = "https://raw.githubusercontent.com/gab-alvarez/unahurhub/refs/heads/main/UNaHurHub/logoModoClaro.png"
$logoModoClaro = "logoModoClaro.png"

$urlImagenJupyter = "https://upload.wikimedia.org/wikipedia/commons/thumb/3/38/Jupyter_logo.svg/883px-Jupyter_logo.svg.png"
$logoJupyter = "logoJupyter.png"

try {
  Invoke-WebRequest -Uri $urlImagenFavicon -OutFile $logoFaviconOriginal
  Invoke-WebRequest -Uri $urlImagenModoOscuro -OutFile $logoModoOscuro
  Invoke-WebRequest -Uri $urlImagenModoClaro -OutFile $logoModoClaro
  Invoke-WebRequest -Uri $urlImagenJupyter -OutFile $logoJupyter
}
catch {
  Write-Host "Ocurrio un error al descargar la imagen." -ForegroundColor Red
  Write-Host "El error es: $($_.Exception.Message)" -ForegroundColor Red
  return
}

# Convierte el archivo original a .ico 
magick $logoFaviconOriginal -resize 128x128 $logoFavicon

if (-not (Test-Path -Path $logoFavicon -PathType Leaf)) {
  Write-Error "¡ERROR CRÍTICO! El archivo '$logoFavicon' no se pudo crear. No se puede continuar con la construcción de Docker."
  Exit
}

# Crea la página de inicio por defecto
@"
<!DOCTYPE HTML>
<html lang="es">

<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{% block title %}UNAHUR-HUB{% endblock %}</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.8/dist/css/bootstrap.min.css" rel="stylesheet"
        integrity="sha384-sRIl4kxILFvY47J16cr9ZwB07vP4J8+LH7qKQnuqkuIAvNWLzeN8tE5YBujZqJLB" crossorigin="anonymous">
    <link rel="stylesheet" href="/custom-static/css/custom.css" />

    <link rel="icon" href="/custom-static/media/favicon.ico" />
</head>

<body>

    <nav class="navbar navbar-expand-lg">
        <div class="container">
            {% block logo %}
            <a class="navbar-brand" href="{{ base_url }}">
                <img src="/custom-static/media/logo.png" alt="Logo" height="40" id="navbar-logo">
            </a>
            {% endblock %}

            <div class="navbar-nav ms-auto d-flex flex-row align-items-center">

                <button id="dark-theme-toggle" class="btn btn-outline-secondary me-3" title="Cambiar tema">
                </button>

                {% if user %}
                <span class="navbar-text me-3 themed-text">
                    Bienvenido, {{ user.name }}
                </span>
                <a class="btn btn-outline-primary" href="{{ logout_url }}">
                    Cerrar Sesión
                </a>
                {% endif %}
            </div>
        </div>
    </nav>

    <main class="container mt-4">
        {% block main %}{% endblock %}
    </main>

    <footer class="custom-footer mt-5">
        <div class="container text-center">
            <img src="/custom-static/media/logoJupyter.png" alt="Logo Jupyter" height="80" class="me-2">
        </div>
    </footer>
    {% block script %}{% endblock %}
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.8/dist/js/bootstrap.bundle.min.js"
        integrity="sha384-FKyoEForCGlyvwx9Hj09JcYn3nv7wiPVlz7YYwJrWVcXK/BmnVDxM+D2scQbITxI"
        crossorigin="anonymous"></script>
    <script src="/custom-static/js/custom.js"></script>
</body>

</html>
"@ | Set-Content -Path "page.html"

# Crea la página de error personalizada
@"
{% extends "page.html" %}

{% block main %}
<div class="login-container" style="min-height: 60vh;">
  <div class="login-card text-center">
    <div class="login-header">

      {# --- Lógica para el Título Personalizado --- #}
      {# Si el error es 403 (Acceso Denegado), muestra un título amigable. #}
      {% if status_code == 403 %}
        <h2 class="text-warning mb-3">Acceso Restringido</h2>
      
      {# Para cualquier otro error, muestra el título estándar. #}
      {% else %}
        <h2 class="text-danger mb-3">Error {{ status_code }}: {{ status_message }}</h2>
      {% endif %}

    </div>
    <div class="login-body">
      {# Este es el mensaje que enviaste desde jupyterhub_config.py #}
      <p class="lead">{{ message }}</p>
      <hr>
      <p>
        Si crees que esto es un error, por favor <a href="mailto:soporte@UNaHurHub.com">contacta al soporte</a>.
      </p>
      <a href="{{ base_url }}" class="btn btn-primary mt-3">
        Volver a la Página Principal
      </a>
    </div>
  </div>
</div>
{% endblock main %}
"@ | Set-Content -Path "error.html"

# Customiza el Login
@"
{% extends "page.html" %}

{% block main %}
<div class="container-fluid text-center">
    <div class="card border-primary" id="loginDivContainer">
        <div class="card-body">

            <div class="card-header bg-transparent border-success">Iniciá sesión</div>
            <p class="card-text themed-text">Accede a tu espacio de trabajo</p>

            <a href="{{ authenticator_login_url | safe }}" class="btn btn-primary btn-block"
                role="button">
                <img src="https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_%22G%22_logo.svg" alt="Google icon" class="img-fluid"/>
                Iniciar Sesión con Google
            </a>
            <div class="card-footer bg-transparent themed-text-muted">
                <p>¿Necesitas ayuda? <a href="mailto:soporte@UNaHurHub.com">Contacta soporte</a></p>
            </div>
        </div>
    </div>
</div>
{% endblock main %}
"@ | Set-Content -Path "login.html"

# Configura la página de Home
@'
<!-- home.html -->
{% extends "page.html" %}

{% block main %}
<div class="home-container">
    <!-- Panel de bienvenida -->
    <div class="welcome-panel">
        <h1>¡Bienvenido, {{ user.name }}!</h1>
        <p class="lead">Tu espacio de trabajo personal está listo.</p>
    </div>

    <!-- Servidores del usuario -->
    <div class="servers-section">
        <h2>Mis Servidores</h2>
    </div>
        {% if user.active %}
        <div class="row">
          <div class="no-servers">
            <p>Accedé a tu servidor.</p>
            <a href="/hub/spawn" class="btn btn-primary">
                Accedé a tu servidor
            </a>
        </div>
        </div>
        {% else %}
        <div class="no-servers">
            <p>No tienes servidores configurados.</p>
            <a href="/hub/spawn" class="btn btn-primary">
                Crear Servidor
            </a>
        </div>
        {% endif %}
    </div>
</div>
{% endblock %}
'@ | Set-Content -Path "home.html"

# Crea la página de carga del servidor (spawn-pending)
@'
{% extends "page.html" %}

{% block main %}
<div class="container text-center spawn-container">
  <div class="spawn-card">
    <h1 class="spawn-title">¡Preparando tu espacio de trabajo!</h1>
    <p class="lead themed-text-muted">
      Estamos iniciando tu servidor, {{ user.name }}. Esto puede tardar unos momentos.
    </p>

    <div class="spinner-container">
      <div class="spinner"></div>
    </div>

    <div class="progress" role="barraDeProgreso" aria-label="Animated striped example" aria-valuenow="75"
      aria-valuemin="0" aria-valuemax="100">
      <div id="progress-bar" class="progress-bar progress-bar-striped progress-bar-animated" data-progress-url="{{ progress_url | safe }}">
        <span class="visually-hidden"><span id="sr-progress">0%</span> Completado</span>
      </div>
    </div>

    <div class="log-container">
      <pre id="progress-log" class="log-output"></pre>
    </div>
  </div>
</div>
{% endblock main %}
'@ | Set-Content -Path "spawn_pending.html"

# Crea el archivo CSS
@'
/* --- custom.css --- */
/* Fuentes y Variables de Color para los Temas */
:root {
  --font-family-sans-serif: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
  --font-family-monospace: SFMono-Regular, Menlo, Monaco, Consolas, 'Liberation Mono', 'Courier New', monospace;

  /* TEMA CLARO (Tus colores alegres) */
  --primary-color: #00a3ca;
  --primary-hover-color: #01a4cd;
  --secondary-color: #62ae34;
  --background-color: #fbfbff;
  --text-color: #212529;
  --card-background-color: #ffffff;
  --card-border-color: #e0e0e0;
  --card-shadow: 0 4px 12px rgba(0, 0, 0, 0.08);
  --success-color: #28a745;
  --warning-color: #ffc107;
  --danger-color: #dc3545;
  --navbar-bg: #ffffff;
  --footer-bg: #f8f9fa;
  --text-muted-color: #6c757d;
}

/* TEMA OSCURO (MODIFICADO a tonos verdes y azules) */
[data-theme="dark"] {
  --primary-color: #08d9d6;          /* Un teal brillante (azul-verde) */
  --primary-hover-color: #25eae7;    /* Más brillante */
  --secondary-color: #3ddc84;        /* Un verde lima brillante */
  --background-color: #102a3a;      /* Azul oscuro desaturado (fondo) */
  --text-color: #e0e0e0;             /* Texto claro (casi blanco) */
  --card-background-color: #173d4f; /* Azul/Verde oscuro para tarjetas */
  --card-border-color: #2a526a;     /* Borde ligeramente más claro */
  --card-shadow: 0 4px 15px rgba(0, 0, 0, 0.2);
  --success-color: #3ddc84;          /* Verde lima */
  --warning-color: #ffc107;
  --danger-color: #ff5a5f;
  --navbar-bg: #153243;              /* Azul oscuro para la barra de navegación */
  --footer-bg: #0a1e2b;              /* El azul más oscuro para el pie de página */
  --text-muted-color: #a0a0a0;
}

/* --- Estilos Globales --- */
body {
  font-family: var(--font-family-sans-serif);
  background-color: var(--background-color);
  color: var(--text-color);
  transition: background-color 0.3s ease, color 0.3s ease;
  min-height: 100vh;
  display: flex;
  flex-direction: column;
}

/* --- Clases de Texto Temáticas --- */
/* Para texto que debe seguir el color principal */
.themed-text {
  color: var(--text-color);
}

/* Para texto que debe seguir el color atenuado (muted) */
.themed-text-muted {
  color: var(--text-muted-color);
}

main {
  flex-grow: 1;
}

/* --- Barra de Navegación --- */
.navbar {
  background-color: var(--navbar-bg);
  box-shadow: var(--card-shadow);
  border-bottom: 1px solid var(--card-border-color);
  transition: background-color 0.3s ease;
}

.navbar-brand img {
  transition: transform 0.3s ease, content 0.3s ease;
}

.navbar-brand img:hover {
  transform: scale(1.05);
}

/* --- Botones --- */
.btn {
  border-radius: 8px;
  font-weight: 500;
  transition: all 0.2s ease;
}

.btn-primary {
  background-color: var(--primary-color);
  border-color: var(--primary-color);
}

.btn-primary:hover {
  background-color: var(--primary-hover-color);
  border-color: var(--primary-hover-color);
  transform: translateY(-2px);
  box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
}

.btn-outline-primary {
  color: var(--primary-color);
  border-color: var(--primary-color);
}
.btn-outline-primary:hover {
  background-color: var(--primary-color);
  color: white;
}

.btn-success {
    background-color: var(--success-color);
    border-color: var(--success-color);
}

.btn-warning {
    background-color: var(--warning-color);
    border-color: var(--warning-color);
}

/* --- Tarjetas (Cards) --- */
.card {
  background-color: var(--card-background-color);
  border: 1px solid var(--card-border-color);
  border-radius: 12px;
  box-shadow: var(--card-shadow);
  transition: all 0.3s ease;
}

.card:hover {
  transform: translateY(-5px);
  box-shadow: 0 8px 20px rgba(0, 0, 0, 0.12);
}

.card-header, .card-footer {
  background-color: transparent;
  border-color: var(--card-border-color);
}

/* --- Página de Login --- */
#loginDivContainer {
  max-width: 450px;
  margin: 5rem auto;
  padding: 2rem;
  text-align: center;
}

#loginDivContainer .card-header {
  font-size: 1.5rem;
  font-weight: 600;
  color: var(--primary-color);
  border-bottom: 2px solid var(--primary-color);
}

#loginDivContainer a.btn-primary {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 10px;
  font-size: 1.1rem;
  padding: 12px;
}

#loginDivContainer a.btn-primary img {
    height: 24px;
    background: white;
    border-radius: 50%;
    padding: 2px;
}

/* --- Página de Home --- */
.home-container .welcome-panel {
  padding: 3rem;
  background-color: var(--card-background-color);
  border-radius: 12px;
  margin-bottom: 2rem;
  text-align: center;
}

.server-card .badge {
  font-size: 0.9rem;
  padding: 0.5em 0.8em;
}

/* --- Página de Spawner --- */
.spawn-container {
  display: flex;
  justify-content: center;
  align-items: center;
  min-height: 70vh;
}

.spawn-card {
  max-width: 600px;
  width: 100%;
  padding: 2rem;
  background-color: var(--card-background-color);
  border-radius: 12px;
  box-shadow: var(--card-shadow);
}

.progress {
    height: 20px;
    border-radius: 10px;
    background-color: var(--card-border-color);
}

.progress-bar {
    background-color: var(--primary-color) !important;
    transition: width 0.4s ease-in-out !important;
}

#progress-log {
  margin-top: 1rem;
  background-color: var(--background-color);
  color: var(--text-color);
  border: 1px solid var(--card-border-color);
  border-radius: 8px;
  padding: 1rem;
  min-height: 100px;
  max-height: 200px;
  overflow-y: auto;
  font-family: var(--font-family-monospace);
  white-space: pre-wrap;
  word-break: break-all;
}

/* --- Footer --- */
.custom-footer {
  padding: 1.5rem 0;
  background-color: var(--footer-bg);
  color: var(--text-muted-color);
  margin-top: auto;
  transition: background-color 0.3s ease;
}

/* --- Icono de Tema --- */
#dark-theme-toggle {
    width: 40px;
    height: 40px;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 50%;
}
#dark-theme-toggle svg {
    width: 20px;
    height: 20px;
    fill: currentColor;
}
'@ | Set-Content -Path "custom.css"

# Crea el archivo .js
@'
// --- custom.js ---

document.addEventListener('DOMContentLoaded', function () {

  // --- 1. LÓGICA PARA CAMBIAR ENTRE TEMA CLARO Y OSCURO ---
  const themeToggle = document.getElementById('dark-theme-toggle');
  const htmlElement = document.documentElement;
  // MODIFICACIÓN: Obtener la imagen del logo por su ID
  const logoImage = document.getElementById('navbar-logo'); 

  // Iconos SVG para el botón
  const sunIcon = `
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
      <path d="M12 7c-2.76 0-5 2.24-5 5s2.24 5 5 5 5-2.24 5-5-2.24-5-5-5zM12 9c1.65 0 3 1.35 3 3s-1.35 3-3 3-3-1.35-3-3 1.35-3 3-3zm0-7c.55 0 1 .45 1 1v1c0 .55-.45 1-1 1s-1-.45-1-1V3c0-.55.45-1 1-1zm0 18c.55 0 1 .45 1 1v1c0 .55-.45 1-1 1s-1-.45-1-1v-1c0-.55.45-1 1-1zm-8-9c.55 0 1 .45 1 1h1c0 .55-.45 1-1 1s-1-.45-1-1H3c0-.55.45-1 1-1zm14 0c.55 0 1 .45 1 1h1c0 .55-.45 1-1 1s-1-.45-1-1h-1c0-.55.45-1 1-1zm-9.95-4.95c.39-.39 1.02-.39 1.41 0l.71.71c.39.39.39 1.02 0 1.41-.39.39-1.02.39-1.41 0l-.71-.71c-.39-.39-.39-1.02 0-1.41zm8.49 8.49c.39-.39 1.02-.39 1.41 0l.71.71c.39.39.39 1.02 0 1.41-.39.39-1.02.39-1.41 0l-.71-.71c-.39-.39-.39-1.02 0-1.41zM4.05 4.05c.39-.39 1.02-.39 1.41 0l.71.71c.39.39.39 1.02 0 1.41-.39.39-1.02.39-1.41 0l-.71-.71c-.39-.39-.39-1.02 0-1.41zm8.49 8.49c.39-.39 1.02-.39 1.41 0l.71.71c.39.39.39 1.02 0 1.41-.39.39-1.02.39-1.41 0l-.71-.71c-.39-.39-.39-1.02 0-1.41z"/>
    </svg>`;
  const moonIcon = `
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
      <path d="M12 3c-4.97 0-9 4.03-9 9s4.03 9 9 9c.83 0 1.62-.11 2.36-.32-.34-.41-.62-.88-.8-1.39-.42-1.2-1.2-3.8-1.2-3.8s-.38-1.16.5-1.9c.88-.74 1.98-.38 1.98-.38s2.6 1.18 3.8 1.2c.51.08 1.08.36 1.39.8.21-.74.32-1.53.32-2.36 0-4.97-4.03-9-9-9z"/>
    </svg>`;

  const applyTheme = (theme) => {
    if (theme === 'dark') {
      htmlElement.setAttribute('data-theme', 'dark');
      themeToggle.innerHTML = sunIcon;
      // MODIFICACIÓN: Cambiar al logo oscuro
      if (logoImage) {
        logoImage.src = "/custom-static/media/logoModoOscuro.png";
      }
    } else {
      htmlElement.removeAttribute('data-theme');
      themeToggle.innerHTML = moonIcon;
      // MODIFICACIÓN: Cambiar al logo claro
      if (logoImage) {
        logoImage.src = "/custom-static/media/logoModoClaro.png";
      }
    }
  };

  // Cargar tema guardado o preferido por el sistema
  const savedTheme = localStorage.getItem('theme') || (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
  applyTheme(savedTheme);

  // Listener para el botón
  themeToggle.addEventListener('click', () => {
    const currentTheme = htmlElement.getAttribute('data-theme');
    const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
    localStorage.setItem('theme', newTheme);
    applyTheme(newTheme);
  });


  // --- 2. LÓGICA PARA LA PÁGINA DE CARGA DEL SERVIDOR (SPAWN-PENDING) ---
  // (Sin cambios en esta sección)
  const progressBar = document.getElementById('progress-bar');
  if (progressBar) {
    const log = document.getElementById('progress-log');
    
    const progressUrl = progressBar.getAttribute('data-progress-url');

    // Conectar al stream de eventos del servidor
    const eventSource = new EventSource(progressUrl);

    eventSource.onmessage = function (event) {
      const data = JSON.parse(event.data);
      const timestamp = new Date().toLocaleTimeString();

      // Actualizar la barra de progreso
      if (data.progress !== undefined) {
        const progress = Math.round(data.progress);
        progressBar.style.width = progress + '%';
        progressBar.setAttribute('aria-valuenow', progress);
        const srText = document.getElementById('sr-progress');
        if (srText) {
            srText.textContent = progress + '%';
        }
      }

      // Añadir mensaje al log
      if (data.message) {
        log.textContext += `[${timestamp}] ${data.message}\n`;
        log.scrollTop = log.scrollHeight; // Auto-scroll hacia abajo
      }
      
      // Si el servidor está listo, redirigir
      if (data.ready) {
        eventSource.close();
        window.location.reload();
      }
      
      // Si hay un fallo, detener y mostrar
      if (data.failed) {
          eventSource.close();
          progressBar.classList.add('bg-danger');
          progressBar.style.width = '100%';
          const message = data.message || "¡Error al iniciar el servidor!";
          log.textContent += `[${timestamp}] ERROR: ${message}\n`;
          log.scrollTop = log.scrollHeight;
      }
    };
    
    eventSource.onerror = function (err) {
        console.error("EventSource falló:", err);
        const timestamp = new Date().toLocaleTimeString();
        log.textContent += ["Error de conexión con el servidor. Reintentando...\n"];
        log.scrollTop = log.scrollHeight;
    };
  }
});
'@ | Set-Content -Path "custom.js"

# Parte 3: crea el .env, Dockerfile.

$archivoEnv = ".env"

if (-not (Test-Path -Path $archivoEnv)) {
  # Configuración para Google
  $googleClientID = Read-Host -Prompt '  -> Google Client ID (se encuentra en el archivo .json adjunto)'
  $googleClientSecret = Read-Host -Prompt '  -> Google Client Secret (se encuentra en el archivo .json adjunto)'
  $urlCallback = Read-Host -Prompt '  -> URL (agregarle /hub/oauth_callback, por ejemplo: http://localhost:8890/hub/oauth_callback)'
    
  # Configuración para la base de datos 
  $nombreDeLaBaseDeDatos = Read-Host -Prompt '  -> Nombre para la base de datos'
  $usuarioDeLaBaseDeDatos = Read-Host -Prompt '  -> Usuario para la base de datos'
  $contraseniaBaseDatos = Read-Host -Prompt '  -> Contrasenia para la base de datos'
  $puertoBaseDeDatos = 5432
  # Crea el archivo
  @"
POSTGRES_HOST=db
POSTGRES_PORT=$puertoBaseDeDatos
POSTGRES_DB=$nombreDeLaBaseDeDatos
POSTGRES_USER=$usuarioDeLaBaseDeDatos
POSTGRES_PASSWORD=$contraseniaBaseDatos
GOOGLE_CLIENT_ID=$googleClientID
GOOGLE_CLIENT_SECRET=$googleClientSecret 
OAUTH_CALLBACK_URL=$urlCallback 
"@  | Set-Content -Path "$archivoEnv" -Encoding utf8
}

Write-Host "Configurando Docker..."
@"
FROM python:3.10-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        nodejs \
        npm \
    && npm install -g configurable-http-proxy \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir \
        jupyterhub==5.4.0 \
        oauthenticator \
        dockerspawner \
        jupyterhub-ldapauthenticator \
        psycopg2-binary \
        redis \
        jupyterhub-nativeauthenticator \
        python-dotenv

COPY jupyterhub_config.py /etc/jupyterhub/

# Manejo de archivos .html
RUN mkdir -p /etc/jupyterhub/customizacionPersonalizada/html
COPY page.html /etc/jupyterhub/customizacionPersonalizada/html
COPY login.html /etc/jupyterhub/customizacionPersonalizada/html
COPY home.html /etc/jupyterhub/customizacionPersonalizada/html
COPY spawn_pending.html /etc/jupyterhub/customizacionPersonalizada/html 
COPY error.html /etc/jupyterhub/customizacionPersonalizada/html
# Manejo de archivos .css
RUN mkdir -p /etc/jupyterhub/customizacionPersonalizada/css
COPY custom.css /etc/jupyterhub/customizacionPersonalizada/css
# Manejo de archivos .js
RUN mkdir -p /etc/jupyterhub/customizacionPersonalizada/js
COPY custom.js /etc/jupyterhub/customizacionPersonalizada/js
# Manejo de archivos multimedia
RUN mkdir -p /etc/jupyterhub/customizacionPersonalizada/media
COPY $logoFavicon /etc/jupyterhub/customizacionPersonalizada/media
COPY $logoModoOscuro /etc/jupyterhub/customizacionPersonalizada/media
COPY $logoModoClaro /etc/jupyterhub/customizacionPersonalizada/media
COPY $logoJupyter /etc/jupyterhub/customizacionPersonalizada/media

EXPOSE 8000
CMD ["jupyterhub", "-f", "/etc/jupyterhub/jupyterhub_config.py"]

"@ | Set-Content -Path "Dockerfile"

# Parte 4: crea el archivo de configuración de JupyterHub
@"
import os
from jupyterhub.handlers.static import LogoHandler
import psycopg2
from oauthenticator.google import GoogleOAuthenticator
import tornado.web
from tornado.web import HTTPError
from dotenv import load_dotenv
import logging
load_dotenv()

# Cargar variables de entorno del archivo .env
load_dotenv()

# Configuración del logging
logging.basicConfig(level=logging.INFO)
log = logging.getLogger(__name__)

c = get_config()

# Configuración de la base de datos 
db_config = {
    'host': os.environ.get('POSTGRES_HOST', 'db'),
    'port': os.environ.get('POSTGRES_PORT', 5432),
    'dbname': os.environ.get('POSTGRES_DB'),
    'user': os.environ.get('POSTGRES_USER'),
    'password': os.environ.get('POSTGRES_PASSWORD'),
}

# Configuración general de JupyterHub
c.JupyterHub.hub_ip = '0.0.0.0'
c.JupyterHub.hub_connect_ip = 'jupyterhub'
c.JupyterHub.hub_port = 8090
c.JupyterHub.default_url = '/hub/home'
c.JupyterHub.db_url = 'sqlite:////etc/jupyterhub/jupyterhub.sqlite'
c.JupyterHub.logo_file = '/etc/jupyterhub/customizacionPersonalizada/media/logo.png'
c.JupyterHub.template_vars = {
    'organization_name': 'UNAHUR-HUB',
    'custom_footer_text': 'UNAHUR-HUB - Versión 2025.2',
}
c.JupyterHub.template_paths = ["/etc/jupyterhub/customizacionPersonalizada/html"]
c.JupyterHub.extra_handlers = [
    (r'/custom-static/(.*)', 'tornado.web.StaticFileHandler', {'path': '/etc/jupyterhub/customizacionPersonalizada/'})
]

# Configuración del spawner 
notebook_dir = '/home/jovyan/work'
c.JupyterHub.spawner_class = 'dockerspawner.DockerSpawner'
c.DockerSpawner.network_name = 'unahurhub-network'
c.DockerSpawner.image = os.environ.get('DOCKER_NOTEBOOK_IMAGE', 'jupyter/scipy-notebook:latest')
c.DockerSpawner.remove = False
c.DockerSpawner.notebook_dir = notebook_dir
c.DockerSpawner.volumes = {
    'jupyterhub-user-{username}': notebook_dir
}

def init_db():
    # Crea dos tablas, una para los usuarios y otra para el estado que tengan (pendiente, aprobado o rechazado)
    conn = None
    cursor = None
    try:
        conn = psycopg2.connect(**db_config)
        cursor = conn.cursor()

        # Crea la tabla para el estado
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS estado_cuenta (
                id_estado_cuenta INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                estado VARCHAR(50) UNIQUE NOT NULL
            );
        """)

        cursor.execute("CREATE EXTENSION IF NOT EXISTS CITEXT;")

        # Crea la tabla para las cuentas
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS cuenta (
                id_cuenta INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                email CITEXT UNIQUE NOT NULL,
                id_estado_cuenta_fk INT,
                FOREIGN KEY (id_estado_cuenta_fk) REFERENCES estado_cuenta (id_estado_cuenta)
            );
        """)

        # Agrega los estados que puede tener una cuenta: pendiente, aprobada o suspendida
        cursor.execute("""
        INSERT INTO estado_cuenta (estado) VALUES
            ('pendiente'),
            ('aprobada'),
            ('suspendida')
            ON CONFLICT (estado) DO NOTHING;
        """)

        conn.commit()
        log.info("Base de datos para aprobación de usuarios inicializada correctamente.")
    except psycopg2.OperationalError as e:
        log.error(f"No se pudo conectar a la base de datos para inicializar: {e}")
        raise
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()

async def check_user_approval(authenticator, handler, auth_model):
    username = auth_model['name']    
    conn = None
    cursor = None
    cuenta_pendiente = 1
    cuenta_aprobada = 2
    cuenta_suspendida = 3
    try:
        conn = psycopg2.connect(**db_config)
        cursor = conn.cursor()
        cursor.execute("""
            SELECT 
                id_estado_cuenta_fk
            FROM cuenta c
            WHERE c.email = %s;
        """, (username,))
        result = cursor.fetchone()
        if result:
            estado_cuenta = result[0]
            if estado_cuenta == cuenta_aprobada:
                log.info("DEBUG: salio todo bien")
                return auth_model
            elif estado_cuenta == cuenta_pendiente:
                raise HTTPError(403, f"Acceso denegado. Tu cuenta '{username}' está en estado pendiente.")
            else:
                raise HTTPError(403, f"Acceso denegado. Tu cuenta '{username}' está en estado suspendida.")
        else:
            cursor.execute("""
                INSERT INTO cuenta (email, id_estado_cuenta_fk) 
                VALUES (%s, (SELECT id_estado_cuenta FROM estado_cuenta WHERE estado = 'pendiente'));
            """, (username,))
            conn.commit()
            raise HTTPError(403, f"Has sido registrado exitosamente. Un administrador debe aprobar tu cuenta '{username}' antes de que puedas iniciar sesión.")
    except psycopg2.Error as e:
        raise HTTPError(500, "Ocurrió un error con la base de datos. Por favor, intenta de nuevo más tarde.")
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()

init_db()

# Configuración de autenticación con Google y método de aprobación hecho 
c.JupyterHub.authenticator_class = 'oauthenticator.google.GoogleOAuthenticator'
c.GoogleOAuthenticator.allow_all = True
c.Authenticator.allowed_users = set()
c.Authenticator.post_auth_hook = check_user_approval
c.GoogleOAuthenticator.client_id = os.environ.get('GOOGLE_CLIENT_ID')
c.GoogleOAuthenticator.client_secret = os.environ.get('GOOGLE_CLIENT_SECRET')
c.GoogleOAuthenticator.oauth_callback_url = os.environ.get('OAUTH_CALLBACK_URL')
c.JupyterHub.admin_access = True
"@ | Set-Content -Path "jupyterhub_config.py"

Write-Host "Pasos a seguir:" -ForegroundColor Green
Write-Host "Copiar el archivo adjunto docker-compose.yml en la carpeta $carpetaDelProyecto (creada dentro de la carpeta que contiene el archivo setup_jupyterhub.ps1)"
Read-Host "Presiona Enter cuando esté el archivo docker-compose.yml listo..."

docker compose up --build

Write-Host "Listo, server corriendo en localhost:8890" -ForegroundColor Green

