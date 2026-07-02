# Inventario — Conexiones Jotform ↔ Vilar KPTL

Generado en la sesión del 2026-07-02. Basado en `grep`/exploración de árbol de
archivos local de los 6 repos (no de GitHub code search, que no indexa estos
repos privados). Todos los conteos son aproximados: los repos contienen
duplicados masivos entre sí (ver sección "Duplicación entre repos").

## 1. Mapa de repos

| Repo | Qué es realmente | Archivos | Nota |
|---|---|---|---|
| `jotform` | Vacío hasta esta sesión | 0 | Ahora es el hub de este proyecto |
| `vilarkptl` | Código fuente real del sitio de Vilar KPTL (financiero: crédito, arrendamiento, inversión, factoraje) | ~500+ | Contiene `google_token.json` y API key de JotForm en texto plano |
| `cPanel` | Volcado crudo de una cuenta de hosting cPanel completa (varios dominios) | ~9000+ solo en `public_html`, más varios `.zip` sin descomprimir | **Sin TypeScript en ningún lado** |
| `ryby.lease` | Volcado crudo con `html/` (duplicado casi completo de `cPanel` + `vilarkptl`) y `catalogos/` (proyectos separados: OCR, auditorías, `credit-agents`) | Miles | Contiene el sistema **más avanzado** encontrado: `credit-agents` (Flask + MySQL, ya migra Jotform → DB) |
| `ryby-lease` (con guion) | Esqueleto mínimo: `api/`, `cms/`, `template/`, `web/` | ~10 | Sin referencias a JotForm todavía — parece un sitio nuevo/separado, no el mismo negocio que `ryby.lease` |
| `db-backups` | Solo `Notion.sql` (44 KB, export de Notion) e `instapay.sql` (60 KB) repetidos en carpetas fechadas | ~20 | **No** son las bases de datos financieras del negocio; esas viven en MySQL de `credit-agents` y/o en JotForm mismo |

### Duplicación entre repos (importante para no re-analizar lo mismo)

- `ryby.lease/html/vilarkptl.com/**` es una copia casi 1:1 de `vilarkptl/**`.
- `ryby.lease/html/cpanel-repo/**` es una copia casi completa de `cPanel/**`.
- `ryby.lease/html/kptl.mx/**` y `ryby.lease/html/cpanel-repo/public_html/kptl.mx/**` se repiten.

Conclusión: el **origen de verdad** para el código de sitio (HTML/JS/PHP) es
`vilarkptl` + `cPanel/public_html`. `ryby.lease/html/*` son snapshots viejos
del mismo contenido — útiles solo para diffing histórico, no para migrar desde
cero.

## 2. Integración JotForm — patrón repetido

Cada "monolito" de negocio (crédito, arrendamiento, inversión, factoraje,
caja de inversión, crédito-nómina, balón, AP-variable, etc.) sigue el mismo
patrón, repetido ~15 veces con variaciones menores:

**Frontend (JS, sin build step, `<script>` sueltos):**
- `js/jotform.js` — abre `https://form.jotform.com/<user>/<slug>?...` con querystring armado desde inputs del formulario/calculadora (`window.open`).
- `js/linkJotform.js` — variante que arma el link con distintos parámetros.
- `js/sendtable.js` / `js/sendBDD.js` / `js/post_coti.js` — envían resultados de calculadoras a un backend propio (no directamente a JotForm).

**Backend (PHP, proxy hacia la API de JotForm):**
- `dashboard/api/jotform-proxy.php` — proxy GET genérico: `?formID=` o `?submissionID=` → llama `api.jotform.com` con la API key del server, nunca la expone al browser. CORS restringido a orígenes de `ALLOWED_ORIGINS` en `config.php`.
- `dashboard/pages/jotform_submit.php` — POST específico para actualizar 3 campos (impago, fechaReestructura, liquidado) de un formulario fijo (`JOTFORM_FORM_ID = 6436426534113682106`).
- `dashboard/assets/js/perfiles/actualizar_jotform.php` — versión más robusta: rate limiting, mapeo de campos por tipo de producto (`FIELD_MAPPINGS`) y por prefijo de contrato (`CLIENT_MAPPINGS`: KINVCP→inversiones, AGA/RBCT→arrendamiento, etc.), logging a archivo.
- `dashboard/api/config.php` (y su gemelo `kptl.mx/dashboard/api2/config.php`) — constantes compartidas: API key, orígenes permitidos, mapeos.

**Sistema más avanzado (`ryby.lease/html/credit-agents/`, Flask + MySQL):**
Este es, con diferencia, el componente más cercano a lo que pediste
("levantar las bases de datos"). Ya existe y ya funciona (o funcionó):

- `api/services/jotform.py` — wrapper de API (GET submissions/questions, POST submissions, agregación de KPIs por producto).
- `api/scripts/migrate_jotform.py` — importa submissions de 5 formularios (`INV`, `CAJA_INV`, `AP`, `CS`, `CN`) a tablas MySQL `fin_contrapartes`, `fin_proyectos`, `fin_amortizacion`, generando tablas de amortización con fórmulas propias (`tools/formulas.py`).
- `api/scripts/migrate_solicitudes_jotform.py` — importa formularios de solicitud (PF `232066679485873`, PM `232066602934858`) a `fin_solicitudes`.
- `api/migrations/*.sql` — 11 migraciones (`001`…`011`) que definen el esquema: `fin_contrapartes`, `fin_proyectos`, `fin_cartera`, `fin_solicitudes`, `ca_sessions`, `ca_documents`, `ca_jobs`, etc.
- `api/routes/cartera.py`, `admin.py`, `underwriting.py`, `chat.py` — API REST sobre esos datos, con agentes (LangGraph-style en `api/agent/`) que usan Claude/Gemini/DeepSeek para análisis de documentos, SAT, OCR, etc.
- Todo el sistema lee credenciales de `api/.env` (patrón correcto), **pero** trae un fallback hardcodeado a la misma API key expuesta (`migrate_jotform.py:51`).

Esto significa que **gran parte de "levantar las bases de datos" ya está
construido**. El trabajo real pendiente no es escribir esto desde cero, sino:
(a) confirmar en qué servidor vive hoy y si sigue corriendo, (b) revisar qué
formularios activos en JotForm **no** están en la lista `FORMS` de
`migrate_jotform.py` (candidatos a "no reportados"), y (c) decidir si se
despliega en staging o se continúa en producción.

## 3. Formularios de JotForm detectados (IDs)

IDs de formulario encontrados por grep de `form.jotform.com/<id>` y
`formID=` en `vilarkptl` + `cPanel/public_html` (superset). **No** se
consultó la API de JotForm en esta sesión — esta lista viene solo del código
fuente, así que puede estar incompleta o desactualizada:

```
221590910932050   222946484437870   231795749129066   231937410713856
232066181103848   232066602934858*  232066679485873*  233525677104860 (jsform)
240286932205858*  240365995108867   240436035647859   240436319945865
240436604686864   240585297574873*  240666519501860*  241126542257048
241345104699055*  241516179036860   241516777091865   241516900942858
241566191413858   241687398070870   241826187786067*  242666766370870
242675779544877   242677252284866   242677546688880   242678000951859
242678156935873   242685936139873   242736306427053   242906860883871
243167507287867   243167527463865   252026778928065   260375518133051
6436426534113682106 (jotform_submit.php, distinto formato de ID)
```
`*` = también aparece en el catálogo `FORMS`/`FORM_PF`/`FORM_PM` de
`migrate_jotform.py` / `migrate_solicitudes_jotform.py` (o sea, ya tiene
migración a MySQL). El resto (~25 IDs) **no tiene migración conocida** — son
el punto de partida más probable para "bases de datos de JotForm valiosas que
no están siendo reportadas". Antes de asumir que están activos, hay que
consultarlos vía la API de JotForm (`GET /form/{id}` da `count`,
`created_at`, `last_submission`) — no se hizo en esta sesión por no usar la
API key real sin autorización explícita.

Además: `checklist/Banregio/index-script.js` referencia un formulario
`260375518133051` con su propio flujo standalone (checklist de documentos
Banregio), independiente del resto.

## 4. Hallazgos de seguridad

### 4.1 API key de JotForm hardcodeada (crítico)
Valor `6e2676fa4067aecefdfae6fca7c4bb41`. El alcance real es mayor de lo que
parecía en el primer barrido:

- **Backend (PHP/Python), ya corregido en la sesión 2026-07-02** — 10
  archivos ahora leen `getenv('JOTFORM_API_KEY')` en vez de tener la key
  literal: `vilarkptl/dashboard/api/config.php`,
  `vilarkptl/dashboard/pages/jotform_submit.php`,
  `cPanel/public_html/{agata.financial,vilarkptl.com}/dashboard/api/config.php`,
  `cPanel/public_html/kptl.mx/dashboard/api2/config.php`,
  `cPanel/public_html/vilarkptl.com/dashboard/pages/jotform_submit.php`,
  `cPanel/public_html/agata.financial/legal/LDOCR/{proxy.php,proxy(2).php,proxy3.php}`
  (solo la línea `$JF_KEY`, no se tocó `$CLAUDE_KEY` — ver §4.3),
  `ryby.lease/html/credit-agents/api/scripts/migrate_jotform.py` (se quitó el
  fallback hardcodeado). **Esto no rota la key** — solo hace que el código ya
  no la tenga escrita; sigue siendo la misma key comprometida hasta que se
  rote en JotForm. El servidor real deberá exportar `JOTFORM_API_KEY` (p.ej.
  vía Apache `SetEnv`, `.htaccess`, o el `.env` de `credit-agents`) o estos
  proxies quedarán sin key (fallan de forma controlada, no con fatal error).
- **Frontend (JS que corre en el navegador) — NO corregido, alcance mucho
  mayor de lo estimado inicialmente:** ~41 archivos `.js` en `vilarkptl` y
  ~146 en `cPanel/public_html` (más sus duplicados en `ryby.lease/html/`)
  tienen la key embebida directamente como `const apiKey = '...'` o
  `const JOTFORM_API_KEY = '...'` — visible para cualquier visitante del
  sitio vía "ver código fuente", sin necesitar acceso al repo. Patrón
  encontrado en `base_num.js`, `bdd.js`, `sendtable.js`, `linkJotform.js`,
  `status_updater.js`, `Banregio/index-script.js`, y decenas más bajo
  `dashboard/assets/js/**`. **Esto no se corrigió porque no es un simple
  cambio de "variable de entorno"** (el navegador no tiene `process.env`):
  requiere decidir si estas llamadas se reescriben para pasar por un proxy
  backend (como `jotform-proxy.php`, que ya existe) o se elimina el uso
  directo de la API de JotForm desde el cliente. Pendiente para Fase 1
  extendida — ver `roadmap.md`.
- **Otros duplicados no tocados a propósito:** las copias en
  `ryby.lease/html/vilarkptl.com/**` y `ryby.lease/html/cpanel-repo/**` son
  snapshots viejos (ver §"Duplicación entre repos"); no se editaron para no
  inflar el diff sin beneficio real de seguridad.

Cualquiera con acceso de lectura al código (o, para las ~187 rutas
frontend, cualquier visitante del sitio) puede leer, escribir y borrar
submissions de todos los formularios de la cuenta. **Acción para el dueño
del negocio:** rotar la key desde el dashboard de JotForm; ningún agente
puede hacerlo por él. El usuario confirmó en la sesión 2026-07-02 que la
rotará él mismo más adelante.

### 4.2 Archivos `.env` reales committeados (crítico, más amplio que JotForm)
`ryby.lease` tiene decenas de archivos `.env` (no `.env.example`) con
credenciales reales de múltiples subsistemas, entre ellos:

```
catalogos/OCR/v59/api/.env
catalogos/OCR/v57/api/.env
catalogos/ocr/v57/api/.env
catalogos/testing/v60/api/.env
catalogos/vk/vilar-agent/api/.env
catalogos/vk/vilar-agent/openclaw/.env
catalogos/vk/vilar-agent-v2/api/.env
catalogos/vk/vilar-agent-v2/openclaw/.env
catalogos/vk/noticias/.env
catalogos/api-node/.env
catalogos/SAT_API/backend/.env
catalogos/aud/jurisprudencia/.env
catalogos/aud/modular/forensicav2/.env
catalogos/aud/pruebas/v6s2*/.env  (7 variantes/backups)
html/credit-agents-testing/api/.env
html/vilarkptl.com/financial-bot/.env
html/cpanel-repo/public_html/api.debitaria.com/.env
```

No se abrió el contenido de estos archivos más allá de lo necesario para
confirmar que son reales (no plantillas) — evitar manejar más secretos de los
imprescindibles. **Recomendación:** tratar esto como un incidente de
exposición de secretos a nivel de organización, no solo de JotForm. Requiere:
1. Inventario completo de qué servicios/API keys están en cada `.env`.
2. Rotación de todas las credenciales reales expuestas.
3. Reescritura del historial de git de `ryby.lease` (o migración a un repo
   nuevo limpio) — los secretos ya están en el historial aunque se borren los
   archivos hoy.
4. Añadir `.env` a `.gitignore` en todos los repos y usar Infisical (como
   describe la guía de docker-sandbox) para secretos de negocio de aquí en
   adelante.

### 4.3 API keys de Anthropic (Claude) hardcodeadas — crítico, riesgo de costo directo

A diferencia de la key de JotForm (riesgo de integridad de datos), una key de
Anthropic filtrada tiene **riesgo económico directo**: cualquiera con acceso
de lectura al repo puede facturar a la cuenta del dueño. Encontradas al menos
**3 keys distintas** (`sk-ant-api03-...`), hardcodeadas como `$CLAUDE_KEY` en:

```
cPanel/public_html/agata.financial/legal/LDOCR/proxy.php      (línea 11)
cPanel/public_html/agata.financial/legal/LDOCR/proxy(2).php   (línea 11)
cPanel/public_html/agata.financial/legal/LDOCR/proxy3.php     (línea 11)
ryby.lease/catalogos/OCR/proxy.php                             (duplicado)
ryby.lease/catalogos/OCR/v55/proxy.php                         (key distinta)
ryby.lease/html/cpanel-repo/public_html/agata.financial/legal/LDOCR/*.php (duplicados)
```

Estos proxies exponen además un endpoint `?action=delete&id=` que borra
submissions de JotForm usando la misma key de JotForm filtrada (§4.1), y un
endpoint `?test&ping` que hace una llamada real a Anthropic para diagnóstico.

Además, se confirmó (sin imprimir valores) que los siguientes `.env` reales
declaran variables de LLM/servicios de terceros — hay que asumir que pueden
tener valores reales y auditarlos uno por uno antes de rotar:

```
ryby.lease/catalogos/OCR/v57/api/.env       → ANTHROPIC_API_KEY, DEEPSEEK_API_KEY, JOTFORM_API_KEY, SECRET_KEY
ryby.lease/catalogos/OCR/v59/api/.env       → ANTHROPIC_API_KEY, OPENAI_API_KEY, GOOGLE_CLIENT_SECRET, JOTFORM_API_KEY, FLASK_SECRET_KEY
ryby.lease/catalogos/ocr/v57/api/.env       → ANTHROPIC_API_KEY, DEEPSEEK_API_KEY, JOTFORM_API_KEY, SECRET_KEY
ryby.lease/catalogos/testing/v60/api/.env   → ANTHROPIC_API_KEY, OPENAI_API_KEY, GOOGLE_CLIENT_SECRET, JOTFORM_API_KEY, FLASK_SECRET_KEY
vilarkptl/DeCabeceraTax/catalogos/SAT_API/php/.env → ANTHROPIC_API_KEY, ANTHROPIC_ADMIN_KEY, GROK_API_KEY, GROQ_API_KEY, PERPLEXITY_API_KEY
vilarkptl/financial-bot/.env                → DEEPSEEK_API_KEY, GOOGLE_API_KEY, FIN_TELEGRAM_BOT_TOKEN, SIM_GV_BOT_TOKEN
```

**El usuario confirmó en la sesión 2026-07-02 que ya tiene identificadas
estas keys de Anthropic** y se encarga de rotarlas por su cuenta — no
requiere acción de un agente para esa parte. Sigue pendiente: auditar el
resto de `.env` listados en §4.2 (no se sabe si tienen valores reales o
vacíos) y decidir si estos proxies (`proxy.php`/`proxy(2).php`/`proxy3.php`,
que parecen builds/versiones sucesivas del mismo endpoint) se consolidan en
uno solo con la key en variable de entorno.

### 4.4 Otros archivos sensibles
- `vilarkptl/google_token.json` — probable token OAuth de Google (Calendar,
  usado por `calendar_listener.php` / `gmailauth.php`). No se abrió su
  contenido.
- `db-backups/*.sql` — dumps de base de datos en un repo de GitHub; aunque
  pequeños (Notion, Instapay), confirman el patrón de subir backups de datos
  reales a git en vez de a almacenamiento cifrado.

## 5. TypeScript — estado actual

**No existe TypeScript en ninguno de los 6 repos.** Ni `cPanel` (que el
pedido original asumía que ya lo tenía) ni `credit-agents` (que es Python +
JS plano) usan TS. "Recrear los monolitos en estilos TypeScript" es trabajo
nuevo desde cero, no una migración de algo existente. Ver Fase 3 en
`roadmap.md`.
