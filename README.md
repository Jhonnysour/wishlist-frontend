# Wishlist (app Android)

App Flutter de una **lista de deseos universal**. Compartes el enlace de un producto de **cualquier
tienda** desde el navegador o desde la app de la tienda, y la app lo guarda con **foto, título,
precio y descripción** en la lista que elijas.

Consume la API [**wishlist-extractor-api**](https://github.com/Jhonnysour/wishlist-extractor-api)
(FastAPI), que hace la extracción.

**Descarga del último APK:**
https://github.com/Jhonnysour/wishlist-frontend/releases/latest/download/app-release.apk

---

## Qué se logró

- **Agregar productos sin escribir nada.** La app aparece en la hoja de *Compartir* de Android:
  compartes el enlace y el producto entra solo a la lista que estabas viendo. También se puede pegar
  la URL a mano.
- **Extracción en vivo.** El item aparece al instante como "Extrayendo…" y la app consulta a la API
  hasta que termina (polling cada 1.8 s, hasta unos 72 s), sin que el usuario tenga que refrescar.
- **Capa 0, el scraping desde el teléfono.** Cuando la API no puede leer una tienda (anti-bot que
  bloquea IPs de servidor, o precios que solo se ven en un navegador real, como en Amazon), la app
  carga la página en un **WebView headless** con la IP residencial y el navegador real del usuario,
  y le envía a la API el HTML ya renderizado. Medido con las mismas URLs: **6/11 sitios desde el
  servidor contra 10/11 desde el teléfono.**
- **Una captura robusta.** El WebView:
  - Ignora los fallos de subrecursos (anuncios, trackers), que antes abortaban la captura.
  - Bloquea las redirecciones a apps nativas (`meli://`, `intent://`).
  - Lee el DOM aunque la página nunca termine de cargar.
  - **Explica por qué falló** cuando falla, y ese detalle se ve en la pantalla del producto.
- **Siempre hay una salida cuando algo falla.** Precio manual, "Completar a mano" para items
  fallidos y, para tiendas que bloquean a propósito (MercadoLibre), un mensaje honesto con un botón
  para **buscar el producto en Amazon**.
- **Listas múltiples con nombre** (crear, renombrar, borrar), con conteos en vivo y sin parpadeos al
  cambiar de lista.
- **Gestión de cada producto:** marcarlo comprado (aparece tachado), renombrarlo, editar el precio,
  elegir qué imágenes conservar y cuál es la portada, borrarlo y copiar el enlace original.
- **Búsqueda y filtros por lista:** texto (busca en el título y en la URL) y estado (todos,
  pendientes o comprados).
- **Cuentas con Supabase Auth.** Registro y login por **username**, sesión persistente con refresh
  automático del token, y cierre de sesión automático ante un 401.
- **Pensada para la capa gratis.** Una pantalla de warm-up espera a que el backend en Render
  despierte (unos 50 s la primera vez) en lugar de mostrar errores.
- **CI/CD:** cada push a `main` compila un APK de release **firmado con una keystore estable**, con
  versionCode incremental, y lo publica en GitHub Releases con una URL de descarga fija.

---

## Stack

| Área | Tecnología |
|---|---|
| Framework | Flutter 3.38.7 · Dart 3.10.7 · Material 3 (semilla "ciruela" `#92355A`) |
| Estado | Riverpod 3 (`AsyncNotifier`, providers `family`) |
| Navegación | go_router 17 (redirect por sesión y por estado del servidor) |
| HTTP | Dio 5 (interceptor de token y de 401) |
| Modelos | freezed 3 + json_serializable (build_runner) |
| Auth | supabase_flutter 2 |
| Capa 0 | flutter_inappwebview 6 (`HeadlessInAppWebView`) |
| Compartir | receive_sharing_intent 1.8.x · url_launcher |
| Plataforma | **Android** únicamente |

---

## Arquitectura

Organización *feature-first*:

```
lib/
  main.dart                       # Supabase.initialize + ProviderScope + MaterialApp.router
  core/
    api/dio_client.dart           # Dio + Bearer de la sesión Supabase + 401 → signOut
    api/api_exception.dart        # Errores de Dio normalizados con mensajes amigables
    config/env.dart               # API_BASE_URL / SUPABASE_* por --dart-define
    router/app_router.dart        # Rutas y redirect (splash → login → warm-up → app)
    theme/app_theme.dart
  features/
    auth/                         # Login / registro (username → email por RPC → Supabase)
    warmup/                       # Espera a que /health responda
    lists/                        # Pantalla principal: CRUD de listas
    wishlist/                     # Items de una lista: alta, polling, detalle, filtros,
                                  #   share target (ShareIntentListener)
    webview_capture/              # Capa 0: captura del HTML con WebView headless
  shared/widgets/remote_image.dart  # Image.network con placeholder ante hotlink 403
test/
  widget_test.dart                # Smoke: sin sesión → pantalla de login
  wishlist_list_switch_test.dart  # Sin parpadeos al cambiar de lista; filtros por lista
```

### Rutas

```
/warmup                     splash mientras se lee la sesión y espera del backend
/login, /register
/                           listas del usuario
/lists/:id                  items de la lista
/lists/:id/add              agregar por URL
/lists/:id/item/:itemId     detalle del producto
```

### Flujo de un producto

```
Compartir enlace ─► POST /items {url, list_id} ─► item PENDING (optimista)
                         │
                         ▼ polling GET /items/{id}
              ┌── COMPLETED con precio ──► listo
              └── FAILED o sin precio ──► Capa 0 (una sola vez por item):
                     WebView headless → HTML → POST /items/{id}/retry-from-html
                         ├── llegaron datos ──► listo
                         └── no llegaron ──► diagnóstico visible + "Completar a mano"
                                              (+ "Buscarlo en Amazon" si es MercadoLibre)
```

### Decisiones de diseño destacables

- **Un controller por lista** (`wishlistControllerProvider` es una *family* por `listId`). Al abrir
  otra lista se monta un estado nuevo en `loading` y no se ven, ni por un instante, los items de la
  anterior. No es `autoDispose` a propósito: el polling de un alta tiene que seguir aunque el
  usuario vuelva atrás.
- **Los filtros también van por lista**, para que una búsqueda no se arrastre a otra lista.
- **El login conserva el username** sobre Supabase, que inicia sesión por email: un RPC resuelve
  `username → email` y luego se llama a `signInWithPassword`.
- **El diagnóstico de captura vive solo en memoria.** Es información de depuración del intento, no
  un dato que haya que guardar.

---

## Puesta en marcha

Requisitos: Flutter 3.38.7, Android SDK y un backend corriendo (local o en Render).

```bash
flutter pub get
dart run build_runner build      # genera *.freezed.dart / *.g.dart
```

### Variables (`--dart-define`)

| Variable | Uso |
|---|---|
| `API_BASE_URL` | URL del backend. Si no se pasa: `http://10.0.2.2:8000` en el emulador Android |
| `SUPABASE_PUBLISHABLE_KEY` | Clave publicable de Supabase (`sb_publishable_…`). **Obligatoria** |
| `SUPABASE_URL` | Opcional; por defecto usa la URL del proyecto |

### Ejecutar

```bash
# Emulador (backend local en el puerto 8000)
flutter run --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...

# Teléfono por USB: mapea el puerto con adb reverse y lanza en un solo paso (PowerShell)
./run-phone.ps1 --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...

# Contra el backend en la nube
flutter run --dart-define=API_BASE_URL=https://<app>.onrender.com \
            --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
```

### Calidad

```bash
flutter analyze
flutter test
```

---

## CI/CD: APK por GitHub Actions

`.github/workflows/build-apk.yml` corre en cada push a `main` y también se puede lanzar a mano:

1. Compila con Flutter 3.38.7 y Java 17.
2. Firma con la keystore de release desde los *secrets* `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`,
   `KEY_PASSWORD` y `KEY_ALIAS`. Si faltan, usa la firma debug. Con una firma estable, cada APK nuevo
   se instala encima del anterior.
3. Toma la versión de `pubspec.yaml` y usa `github.run_number` como **versionCode**.
4. Inyecta `API_BASE_URL` y `SUPABASE_PUBLISHABLE_KEY` desde las *Variables* de Actions.
5. Reemplaza el release `latest`: siempre hay **uno solo**, con el tag sobre el commit compilado, y
   su cuerpo incluye el SHA y el versionCode.

---

## Notas de compatibilidad (pins intencionales)

- `flutter_secure_storage ^9.2.4` y `path_provider_foundation: 2.4.1` (override). Las versiones
  nuevas traen `objective_c` con un *build hook* nativo que rompe `build_runner` en Dart 3.10. Solo
  afectan a Apple, así que son inocuos en Android.
- `json_annotation >=4.9.0 <4.10.0`, por compatibilidad con `json_serializable`.
- `receive_sharing_intent >=1.8.1 <1.9.0`. La 1.9.0 trae un `build.gradle` roto con AGP 8.11.
- `AndroidManifest.xml` declara `<queries>` para `VIEW https`. Sin eso, desde Android 11
  `url_launcher` no encuentra el navegador.
- `network_security_config.xml` permite HTTP en claro para desarrollo contra un backend local. En
  producción la API se sirve por HTTPS.

---

## Limitaciones conocidas

- **MercadoLibre** no se puede leer: redirige incluso al WebView del teléfono a su muro de
  verificación. La app lo dice claro, toma el nombre del enlace y ofrece buscar en Amazon o
  completar el precio a mano.
- Solo Android. Sin iOS ni web por ahora.
- Los tests cubren el arranque sin sesión y el cambio entre listas. Faltan tests de las pantallas
  de detalle y de la Capa 0.

---

## Historia del proyecto

| Fecha (2026) | Hito |
|---|---|
| 17 jul | Scaffold (Riverpod, go_router, Dio, freezed), auth, lista con alta y polling, Share Target de Android, script `run-phone.ps1`, detalle con acciones y búsqueda/filtros. **Capa 0** con WebView y migración a Supabase Auth |
| 18–20 jul | Curación de imágenes, editar título, workflow del APK, firma con keystore estable |
| 21 jul | Pantalla de warm-up y **listas múltiples con nombre** |
| 25–26 jul | Splash de arranque, mostrar contraseña, compartir a la lista actual, conteos en vivo; fix definitivo del parpadeo entre listas; releases trazables |
| 27 jul | Capa 0 también cuando falta el precio, captura robusta (subrecursos, deeplinks, timeout), diagnóstico visible, precio manual, "Completar a mano", MercadoLibre con mensaje claro + "Buscarlo en Amazon" |

El detalle de cada cambio, con el diagnóstico y el porqué, está en
[Cambios_Realizados.md](Cambios_Realizados.md).
