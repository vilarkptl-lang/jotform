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
Valor `6e2676fa4067aecefdfae6fca7c4bb41`, repetido en **al menos 25 archivos**
distintos entre `vilarkptl`, `cPanel` y `ryby.lease` (config.php, .js, .html,
.py, .env). Cualquiera con acceso de lectura al código puede leer, escribir y
borrar submissions de todos los formularios de la cuenta. **Acción para el
dueño del negocio:** rotar la key desde el dashboard de JotForm; ningún
agente puede hacerlo por él.

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

### 4.3 Otros archivos sensibles
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
