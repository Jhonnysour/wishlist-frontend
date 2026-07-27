# Cambios Realizados

Registro cronológico de los cambios del proyecto **wishlist-frontend** (app Flutter que consume la
API `wishlist-extractor-api`). Cada entrada resume qué se hizo y por qué.

---

## 2026-07-26 — Capa 0: esperar el precio de AliExpress antes de capturar

AliExpress inyecta el precio por un XHR que llega **después** del margen fijo de 3s tras
`onLoadStop`, por lo que el WebView capturaba el HTML sin precio (y el item quedaba sin precio).

- `lib/features/webview_capture/data/webview_capture_service.dart`: en `onLoadStop`, si el host es
  de AliExpress, `_waitForAliPrice` sondea el DOM (cada 500 ms, hasta 12 s) esperando el elemento
  `[class*="price-default--current"]` con un número; captura en cuanto aparece, o al agotar el tope
  (best effort). El resto de sitios mantiene el margen fijo de 3s, sin pagar la espera extra.
- Complementa el fix de **imágenes** de AliExpress en el backend (galería vía `imagePathList`).
- **Verificado:** `flutter analyze` del feature sin issues. En dispositivo: re-agregar el producto de
  AliExpress debería traer precio + galería correctos.

---

## 2026-07-17 — Scaffold inicial (Riverpod, feature-first)

Creación del proyecto desde cero (repo vacío) con la infraestructura base `core/` y un modelo de
dominio para validar el pipeline de codegen. **Alcance: solo scaffold** (sin pantallas de features
todavía).

### 1. Creación del proyecto
- `flutter create . --project-name wishlist_frontend --org com.wishlist --platforms=android`.
- El nombre se fijó explícitamente porque la carpeta `wishlist-frontend` tiene guion, que es inválido
  como nombre de paquete Dart.
- Entorno: Flutter 3.38.7 / Dart 3.10.7. Plataforma: Android.

### 2. Dependencias
- **Runtime:** `flutter_riverpod` (3.x), `dio` (5.10), `go_router` (17.x), `flutter_secure_storage`
  (9.2.x), `freezed_annotation` (3.x), `json_annotation` (4.9.x).
- **Dev (codegen):** `build_runner`, `freezed` (3.x), `json_serializable`.
- **Pins/overrides necesarios** (ver sección "Problemas resueltos"):
  - `json_annotation` fijado a `>=4.9.0 <4.10.0`.
  - `flutter_secure_storage` fijado a `^9.2.4`.
  - `dependency_overrides: path_provider_foundation: 2.4.1`.

### 3. Configuración Android
- `AndroidManifest.xml`: se agregó el permiso `android.permission.INTERNET` y
  `android:networkSecurityConfig="@xml/network_security_config"`.
- Nuevo archivo `android/app/src/main/res/xml/network_security_config.xml`: permite tráfico HTTP en
  claro (`base-config cleartextTrafficPermitted="true"`), necesario porque el backend sirve por
  `http://` sin TLS. Es solo para desarrollo; en producción (HTTPS) debe quitarse o endurecerse.

### 4. Infraestructura `core/`
- `core/config/env.dart`: resuelve la base URL por plataforma. Emulador Android → `10.0.2.2:8000`;
  web/iOS/desktop → `localhost:8000`. Permite override en tiempo de compilación con
  `--dart-define=API_BASE_URL=...` (para el celular físico en la misma WiFi). Expone `apiV1BaseUrl`
  con el prefijo `/api/v1`.
- `core/storage/token_storage.dart`: wrapper de `FlutterSecureStorage` para el token JWT (`read`,
  `write`, `clear`), expuesto como `tokenStorageProvider`.
- `core/api/api_exception.dart`: `ApiException` normalizada + mapeo desde `DioException` (timeouts,
  401, 422, errores de conexión, etc.).
- `core/api/dio_client.dart`: `dioProvider` con `BaseOptions` (base URL, timeouts) e interceptor que:
  inyecta `Authorization: Bearer <token>` cuando existe; ante **401** limpia el token guardado.
- `core/router/app_router.dart`: `routerProvider` con go_router. Rutas placeholder `/` y `/login`;
  `redirect` no-op por ahora (se conectará a la sesión en el milestone de auth).
- `core/theme/app_theme.dart`: temas Material 3 claro/oscuro con `ColorScheme.fromSeed`.
- `lib/main.dart`: `ProviderScope` + `MaterialApp.router` conectado a `routerProvider` y a los temas.

### 5. Modelo de dominio + codegen
- `features/wishlist/domain/item.dart`: modelo `Item` con **freezed** que replica `ItemResponse` del
  backend (incluye enum `ItemStatus { pending, completed, failed }` con `@JsonValue`, `price` como
  `double?`, y mapeo de claves `original_url` / `domain_source`).
- Se ejecutó `dart run build_runner build` → generó `item.freezed.dart` e `item.g.dart` (valida el
  pipeline de codegen completo).

### 6. Problemas resueltos durante el scaffold
- **`json_annotation 4.12` incompatible con `json_serializable`** (por la versión de `analyzer` que
  arrastraba): se fijó `json_annotation` a la línea `4.9.x`.
- **`build_runner` falla bajo Dart 3.10 con "'dart compile' does not support build hooks"**: lo
  causaba el paquete `objective_c` (hook nativo de compilación), arrastrado por
  `flutter_secure_storage 10.x` y por `path_provider_foundation >=2.5.0`. Como la app compila solo
  para Android, se fijó `flutter_secure_storage` a `9.2.x` y se agregó un `dependency_overrides` de
  `path_provider_foundation` a `2.4.1` (última versión sin FFI). Ambos son inocuos para Android.

### 7. Verificación
- `flutter analyze` → **No issues found**.
- `flutter test` (smoke test que arranca la app hasta la pantalla placeholder) → **pasa**.
- `flutter build apk --debug` → **APK generado** (`app-debug.apk`), confirma que la config de Android
  compila.

### 8. Commit
- Commit inicial `677044d` — `chore: scaffold Flutter app (Riverpod core infra + Item model)` (37
  archivos).

### 9. Limpieza de avisos del analizador (post-commit)
- Se reescribieron dos comentarios `// TODO(auth): ...` (en `dio_client.dart` y `app_router.dart`) que
  el analizador de Dart marcaba como avisos. Se reformularon como "Auth milestone: ..." conservando la
  nota, sin la palabra clave `TODO`. `flutter analyze` vuelve a estar limpio.

---

## 2026-07-17 — Milestone Auth (login / registro / sesión)

Autenticación completa contra el backend, con protección de rutas por sesión.

### 1. Capa de datos
- `features/auth/data/auth_repository.dart`: `AuthRepository` con:
  - `login()` → `POST /login` **form-urlencoded** (`username`+`password`), devuelve `access_token`.
  - `register()` → `POST /users` JSON (`email`,`username`,`password`).
  - Errores de Dio mapeados a `ApiException`. Expuesto como `authRepositoryProvider`.

### 2. Controlador de sesión
- `features/auth/presentation/providers/auth_controller.dart`: `AuthController` (AsyncNotifier de
  Riverpod 3.x) con estado `bool` = sesión activa. `build()` la deriva de la presencia del token en el
  almacenamiento seguro (el backend no tiene `/me`). Métodos `login`, `register` (con auto-login tras
  crear la cuenta) y `logout`. Provider: `authControllerProvider`.

### 3. Pantallas
- `features/auth/presentation/screens/login_screen.dart` y `register_screen.dart`:
  `ConsumerStatefulWidget` con formularios validados, estado de envío (spinner en el botón), manejo de
  errores por `SnackBar` y navegación cruzada login↔registro.

### 4. Router protegido
- `core/router/app_router.dart`: rutas `/` (home), `/login`, `/register`. `redirect` según
  `authControllerProvider` (sin sesión → `/login`; con sesión en pantalla de auth → `/`; durante la
  lectura inicial del token no redirige). `refreshListenable` puenteado desde el provider con un
  `ValueNotifier` + `ref.listen`. La home ahora es un placeholder autenticado con botón de logout en
  el AppBar.

### 5. Manejo de 401
- `core/api/dio_client.dart`: ante un 401 el interceptor limpia el token **e** invalida
  `authControllerProvider`, de modo que la sesión pasa a "no autenticado" y el router redirige a
  `/login` automáticamente.

### 6. Verificación
- Smoke test actualizado (`test/widget_test.dart`): con un `TokenStorage` fake en memoria y sin token,
  la app arranca en la pantalla de login. `flutter analyze` → **No issues**; `flutter test` → **pasa**.
- Nota: `AsyncValue` en Riverpod 3.x usa `.value` (no existe `valueOrNull`).

### 7. Pendiente de commit
- Este milestone (Auth) + la limpieza de avisos y `Cambios_Realizados.md` de la sección anterior se
  commitearán juntos.

---

## 2026-07-17 — Paleta de color + Milestone Lista y Alta con polling

### Paleta "Ciruela profundo"
- `core/theme/app_theme.dart`: color semilla cambiado a `#92355A` (ciruela). Se agregó la constante
  `AppTheme.purchased = #4F7C82` (verde azulado) para el estado "comprado". Material 3 deriva el resto
  de la paleta desde la semilla.

### Textos a español neutro
- Se corrigió el voseo rioplatense en `login_screen.dart` y `register_screen.dart`
  (`tenés`→`tienes`, `Ingresá`→`Ingresa`, `Registrate`→`Regístrate`, `Iniciá`→`Inicia`).

### Lista de deseos (`GET /items`) + Alta con polling (`POST /items`)
- `shared/widgets/remote_image.dart`: `RemoteImage` con `Image.network` + `errorBuilder` (placeholder
  ante hotlink 403) y `loadingBuilder`.
- `features/wishlist/data/wishlist_repository.dart`: `WishlistRepository` con el CRUD completo
  (`fetchItems`, `fetchItem`, `addItem`, `setPurchased`, `deleteItem`). Provider:
  `wishlistRepositoryProvider`. (PATCH/DELETE quedan listos para el milestone de detalle.)
- `features/wishlist/presentation/providers/wishlist_providers.dart`: `WishlistController`
  (AsyncNotifier de `List<Item>`). `build()` observa la sesión (`authControllerProvider`): trae items
  al iniciar sesión y vacía la lista al cerrarla. `addByUrl` inserta el item PENDING de forma optimista
  y hace **polling** a `GET /items/{id}` cada 1.8 s (hasta 40 intentos ≈ 72 s) hasta COMPLETED/FAILED.
  `refresh` para pull-to-refresh.
- `features/wishlist/presentation/widgets/item_card.dart`: tarjeta que se adapta al `status`
  (PENDING = "Extrayendo…" con spinner; FAILED = mensaje de error + URL; COMPLETED = imagen/título/
  precio/dominio). Si `purchased`, tacha el título y muestra un chip "Comprado".
- `features/wishlist/presentation/screens/wishlist_screen.dart`: home real. Estados loading/error/vacío,
  `RefreshIndicator` (pull-to-refresh) y FAB "Agregar".
- `features/wishlist/presentation/screens/add_item_screen.dart`: pega la URL (con validación http/https
  y botón "Pegar" desde el portapapeles), llama `addByUrl` y vuelve a la lista.
- `core/router/app_router.dart`: `/` ahora es `WishlistScreen`; se agregó la subruta `/add`. Se eliminó
  el placeholder de home.

### Verificación
- `flutter analyze` → **No issues**; `flutter test` (smoke) → **pasa**; build debug de Android → OK.
- Nota: aún **sin commitear** (se junta con la limpieza previa y este milestone).

---

## 2026-07-17 — Share Target de Android (compartir enlaces a la app)

Ahora la app aparece en la hoja de "Compartir" de Android para texto/enlaces. Al elegirla, se dispara
el mismo flujo que el alta manual (`addByUrl` + polling). El botón "Agregar" manual se conserva igual.

- Dependencia: `receive_sharing_intent` fijado a `>=1.8.1 <1.9.0` (platform channels, sin hooks
  nativos). La 1.9.0 tiene un `android/build.gradle` roto (`Could not find method kotlin()`, asume
  AGP 9.x); la 1.8.1 compila con nuestro AGP 8.11 / Kotlin 2.2.20.
- `android/gradle.properties`: se agregó `kotlin.jvm.target.validation.mode=warning`. El plugin 1.8.1
  no fija `jvmTarget`, así que su Java compila a 1.8 y su Kotlin al JDK del build (21); al ser un
  plugin de channels sin código Java propio, se degrada esa validación para que el build no falle.
- `android/app/src/main/AndroidManifest.xml`: se agregó un `intent-filter` de
  `action.SEND` con `mimeType="text/*"` y se cambió `launchMode` de `singleTop` a `singleTask` (para
  reutilizar la instancia cuando llega un intent compartido, según recomienda el paquete).
- `features/wishlist/presentation/providers/wishlist_providers.dart`: nuevo
  `pendingSharedUrlProvider` (`Notifier<String?>` — en Riverpod 3.x `StateProvider` es legacy) que
  guarda la URL compartida a la espera de sesión.
- `features/wishlist/presentation/widgets/share_intent_listener.dart`: `ShareIntentListener` que
  envuelve la app. Escucha `getInitialMedia()` (app abierta desde compartir en frío) y
  `getMediaStream()` (app viva), extrae la primera URL `http(s)` del texto compartido, la publica en
  `pendingSharedUrlProvider` y —si hay sesión— navega a la lista y llama `addByUrl`. Si no hay sesión,
  el enlace queda en espera y se agrega automáticamente tras iniciar sesión. Incluye un
  `scaffoldMessengerKey` global para los SnackBars de feedback.
- `main.dart`: la app se envuelve en `ShareIntentListener` y se pasa `scaffoldMessengerKey` al
  `MaterialApp.router`.

### Verificación
- `flutter analyze` → **No issues**; `flutter test` (smoke) → **pasa**; build debug de Android → OK.

---

## 2026-07-17 — Automatización del lanzamiento en el teléfono (DX)

Para evitar correr varios comandos manuales de `adb`/`flutter` cada vez que se prueba en el teléfono,
se agregaron dos vías de un solo paso (ambas usan `adb reverse` + `--dart-define` a localhost; no se
tocó `env.dart`):

- `run-phone.ps1` (raíz): script en **ASCII puro** (Windows PowerShell 5.1 lee los .ps1 sin BOM como
  ANSI y los acentos rompían la sintaxis). Resuelve `adb` por ruta completa, verifica que haya un
  teléfono conectado, avisa (no bloqueante) si el backend no responde en `:8000`, hace el reverse y
  lanza `flutter run --dart-define=API_BASE_URL=http://localhost:8000` (reenvía args extra con `@args`).
- `.vscode/tasks.json`: tarea `adb-reverse` (mapea el puerto, salida silenciosa).
- `.vscode/launch.json`: configs "Wishlist (teléfono, localhost)" (con `preLaunchTask: adb-reverse` y
  `toolArgs` del dart-define) y "Wishlist (emulador)". Con el teléfono enchufado, basta **F5**.

### Verificación
- Sintaxis del script validada con el parser de PowerShell; `tasks.json`/`launch.json` son JSON válido.
- ExecutionPolicy del usuario = `RemoteSigned` (efectiva `Bypass`) → el script corre sin ajustes.

---

## 2026-07-17 — Milestone Detalle + acciones + búsqueda/filtros (último del plan original)

Completa el CRUD de la wishlist desde la UI y agrega búsqueda/filtros.

### Controller y providers (`wishlist_providers.dart`)
- `build()` ahora observa `wishlistFilterProvider` y hace `fetchItems(q, purchased)`; se re-ejecuta al
  cambiar los filtros. Se extrajo `_fetch(filter)` reutilizado por `build` y `refresh`.
- Nuevos métodos en `WishlistController`: `togglePurchased(id)` (PATCH) y `remove(id)` (DELETE), que
  actualizan la lista en memoria.
- `itemByIdProvider` (Provider.family): un item por id, reactivo (se actualiza con el polling y las
  acciones; `null` si se borró).
- `WishlistFilter` (record `({String query, bool? purchased})`) + `WishlistFilterNotifier` +
  `wishlistFilterProvider`. Se agregó `collection: ^1.19.1` como dependencia directa (para
  `firstOrNull`).

### Pantalla de detalle (`item_detail_screen.dart`)
- Galería de imágenes (`PageView` + indicadores) con `RemoteImage`, título, precio, descripción,
  dominio y URL (con botón de copiar). Se adapta a PENDING/FAILED/COMPLETED.
- Acciones: botón inferior "Marcar como comprado / pendiente" (PATCH, con acento
  `AppTheme.purchased`) y eliminar en el AppBar (con diálogo de confirmación → DELETE → vuelve a la
  lista). Si el item deja de existir, muestra un estado neutro.

### Lista (`wishlist_screen.dart`)
- Barra de búsqueda con debounce (400 ms) → `q`, y `FilterChip`s Todos/Pendientes/Comprados →
  `purchased`. `skipLoadingOnReload: true` para no parpadear al filtrar. Estado vacío distingue
  "lista vacía" de "sin resultados". Las tarjetas ahora navegan al detalle (`/item/:id`).

### Router (`app_router.dart`)
- Nueva subruta `item/:id` → `ItemDetailScreen`.

### Verificación
- `flutter analyze` → **No issues**; `flutter test` (smoke) → **pasa**; build debug de Android → OK.

---

## 2026-07-26 — Fix real del parpadeo de items al cambiar de lista

Al abrir una lista se veían por unos ms los items de la lista anterior. El intento previo
(`d399e68`, agregar `ref.invalidate(wishlistControllerProvider)` en el `onTap`) **no cambiaba nada
en pantalla**; el bug seguía en el APK publicado.

### Por qué el intento anterior no servía
`_ItemList` usa `.when(skipLoadingOnReload: true, …)` y `skipLoadingOnRefresh` **ya vale `true` por
defecto** en riverpod. Con las dos banderas activas, cualquier estado de carga que arrastre un valor
previo se salta el spinner y pinta los items viejos:

- **Antes:** cambiar `currentListIdProvider` era un cambio de dependencia → `isReloading` → tapado
  por `skipLoadingOnReload`.
- **Con el `invalidate`:** `asReload: false` (el default) deja el estado como
  `AsyncData(valor previo, loading)` → `isRefreshing` → tapado por `skipLoadingOnRefresh`.

El `invalidate` solo cambiaba **cuál** de las dos banderas silenciaba el spinner. Y `asReload: true`
tampoco alcanzaba: riverpod conserva el valor previo durante la carga en todos los casos
(`AsyncValue.copyWithPrevious`); solo cambia cómo se etiqueta.

La causa raíz era de diseño: un único `wishlistControllerProvider` global cuya identidad **no
incluía el `listId`** (vivía aparte, en un provider mutable), así que los items de dos listas
compartían el mismo estado.

### Solución: el `listId` pasa a ser parte de la identidad del provider
- `wishlistControllerProvider` → `AsyncNotifierProvider.family<…, String>`. `WishlistController`
  recibe el `listId` por constructor y desaparecen todos los `ref.read(currentListIdProvider)` y sus
  guardas de `null`. Abrir una lista monta un provider nuevo, sin valor previo, así que `when()`
  entra por `loading()` **sin depender de ninguna bandera**.
- Se mantiene `skipLoadingOnReload: true`: ahora solo aplica a recargas por filtro dentro de la
  misma lista, que es para lo que se agregó.
- **No es `autoDispose` a propósito:** `addByUrl` hace polling de hasta ~72 s y tiene que sobrevivir
  a que el usuario vuelva a la pantalla de listas.
- `wishlistFilterProvider` → family por `listId`. Antes el filtro era global y se arrastraba entre
  listas (abrías otra y salía filtrada con el campo de búsqueda vacío). Además `_FilterBar` ahora
  inicializa su `TextEditingController` con la búsqueda guardada de esa lista.
- `itemByIdProvider` → family sobre `({String listId, String itemId})`.
- `currentListIdProvider` se queda, pero ya no decide qué items se cargan: su único uso es que un
  enlace compartido caiga en la lista que se estaba viendo.
- `AddItemScreen` e `ItemDetailScreen` reciben `listId`; el router lo propaga desde el `:id` que ya
  estaba en el path. Se quitó el `invalidate` del `onTap` de `_ListCard`.

Efecto secundario bienvenido: volver a una lista ya visitada la muestra al instante, sin refetch.

### Verificación
- Nuevo `test/wishlist_list_switch_test.dart`: abrir otra lista rinde `spinner` y no los items de la
  anterior (ni el "vacío"), volver a una lista ya cargada la muestra al instante, filtrar dentro de
  una lista no parpadea, y los filtros no se cruzan entre listas.
- `flutter analyze` → **No issues**; `flutter test` → **6 tests pasan**.

---

## 2026-07-26 — Releases trazables: un APK ↔ un commit

La página del Release mostraba el commit `9676238` (20 jul) mientras el APK servido era del 25 jul
18:08, construido desde `d399e68` (25 jul 17:52). El APK era el correcto; la metadata mentía.

Causa: `softprops/action-gh-release` solo crea el tag si no existe. Como `latest` ya apuntaba a
`9676238`, cada run subía un APK nuevo al mismo release **sin mover el tag**. Consecuencias reales,
más allá de lo cosmético:

- El "Source code" del release se genera desde el tag, o sea 6 commits atrás: no correspondía al APK.
- No había forma de mapear un APK a un commit (justo la duda que originó todo esto).
- Todos los APK salían como versionName `1.0.0` / versionCode `1`: el workflow nunca pasaba
  `--build-name`/`--build-number`, así que era imposible saber qué build había instalado.
- Sin historial ni rollback: un único asset que se sobrescribía.

### Cambios (`.github/workflows/build-apk.yml`)
- Paso nuevo que deriva la versión: el nombre sale de `pubspec.yaml` (sigue correcto al subir a
  1.1.0 sin tocar el workflow) y el build number de `github.run_number`, que es monotónico.
- `flutter build apk` ahora recibe `--build-name` y `--build-number`, así que el versionCode sube en
  cada build y Android distingue las instalaciones.
- Un release inmutable por build, con tag `v<version>+<run_number>`. Como el tag se crea nuevo en
  cada run, GitHub lo ancla al commit construido: el commit mostrado y el "Source code" son
  correctos **por construcción**, sin depender de mover tags. El cuerpo incluye el SHA y el
  versionCode. Quedan los APK anteriores para rollback.
- `make_latest: true` mantiene viva la URL de descarga fija, que es la que conviene usar:
  `https://github.com/Jhonnysour/wishlist-frontend/releases/latest/download/app-release.apk`

El release viejo `Latest APK` y su tag `latest` quedan huérfanos; GitHub le mueve la insignia
"Latest" al nuevo automáticamente, así que no estorban.

### Verificación
- El snippet que deriva la versión, probado contra el `pubspec.yaml` actual → `name=1.0.0`,
  `tag=v1.0.0+<run>`. La validación real del YAML es el primer run en Actions.

---

## Pendiente (próximos milestones)
- **Auth:** pantallas login/register, `auth_controller` (AsyncNotifier), persistencia del token,
  `redirect` de go_router + wiring del 401→login. (`/login` es form-urlencoded con `username`+`password`.)
- **Wishlist:** lista (`GET /items`), alta con polling PENDING→COMPLETED (`GET /items/{id}`), detalle +
  `PATCH {purchased}` / `DELETE`, búsqueda/filtros (`q`, `purchased`), widget `RemoteImage` con
  `errorBuilder` para el hotlink 403.
- **Backend CORS:** solo si se apunta a Flutter Web; vive en el repo aparte `wishlist-extractor-api`.
