# Journal — bitácora de sesiones

## Sesión 2026-07-02 (agente: Claude, sesión inicial del proyecto)

**Pedido del usuario (resumen):** montar un sandbox Docker para explorar de
forma segura los 6 repos de la org, mapear todas las conexiones a JotForm en
los sitios de Vilar KPTL, "levantar" en un servidor de staging las bases de
datos del negocio, y recrear los monolitos HTML en TypeScript, priorizando
formularios de JotForm activos que no estén siendo reportados. Pidió
explícitamente `roadmap.md` y `journal.md` para continuidad entre agentes.

**Contexto real de esta sesión (importante):** esta sesión corrió en un
entorno de ejecución remoto de Claude Code con acceso *solo* a 6 repos de
GitHub (`jotform`, `cPanel`, `ryby.lease`, `ryby-lease`, `vilarkptl`,
`db-backups`), ya clonados localmente en `/home/user/*` sobre la rama
`claude/jotform-docker-sandbox-setup-wkulto`. **No hubo acceso** a ningún
servidor de staging real, Docker daemon externo, VPN, Infisical, ni
credenciales de Cloudflare/AWS. La guía de docker-sandbox que compartió el
usuario describe un flujo para *otro* entorno (un servidor real con SSH) —
aquí se documenta y se deja el scaffold, pero no se ejecutó.

**Qué se hizo:**
1. Se intentó `search_code` de GitHub para buscar "jotform" en los repos —
   devolvió 0 resultados en todos los casos, incluso para strings que se
   sabían presentes (`calendar_listener`). Conclusión: el code search de
   GitHub no indexa estos repos privados (o tiene demora); no usar ese tool
   para este tipo de auditoría, usar grep local en su lugar.
2. Se confirmó que los repos ya estaban clonados en `/home/user/` con la
   rama de trabajo activa (excepto `jotform`, que no tenía commits).
3. Se hizo `grep -ri jotform` sobre los 6 repos → cientos de archivos. Se
   armó el inventario completo en `INVENTORY.md`.
4. Se leyeron los archivos clave de integración
   (`vilarkptl/dashboard/api/config.php`, `jotform-proxy.php`,
   `jotform_submit.php`, `actualizar_jotform.php`, `global/js/jotform.js`) y
   se encontró una **API key de JotForm hardcodeada en texto plano**
   (`6e2676fa4067aecefdfae6fca7c4bb41`), repetida en ~25 archivos entre
   `vilarkptl`, `cPanel` y `ryby.lease`.
5. Se preguntó al usuario (`AskUserQuestion`) qué hacer con ese hallazgo y
   cuál era el alcance real esperado para la sesión, dado que no había acceso
   a infraestructura real. Respuestas:
   - No tocar código todavía, solo documentar el hallazgo.
   - Entregable de hoy: scaffold de docker-sandbox + inventario + roadmap.
   - Hub central: repo `jotform` (estaba vacío).
6. Se exploró `cPanel` (repo de backup de hosting completo, ~9000 archivos en
   `public_html`, varios `.zip`) → **no tiene TypeScript en ningún lado**,
   contradiciendo la premisa del pedido original de que ya existía "estilo
   TypeScript" ahí.
7. Se exploró `ryby.lease` a fondo y se encontraron dos cosas grandes:
   - `ryby.lease/html/credit-agents/` — un sistema Flask + MySQL **ya
     funcional** que migra submissions de JotForm a tablas `fin_contrapartes`,
     `fin_proyectos`, `fin_amortizacion`, `fin_solicitudes` (scripts
     `migrate_jotform.py`, `migrate_solicitudes_jotform.py`, servicio
     `services/jotform.py`, 11 migraciones SQL, rutas Flask, agentes con
     LLMs). Esto es, con diferencia, lo más parecido a "levantar las bases de
     datos" que ya existe — el trabajo pendiente es confirmar si sigue vivo
     en algún servidor, no reconstruirlo desde cero.
   - Decenas de archivos `.env` **reales** (no `.env.example`) committeados
     en `catalogos/` y `html/`, con credenciales de múltiples subsistemas
     (OCR, vilar-agent, noticias, SAT_API, auditorías, financial-bot,
     api.debitaria.com). Esto es un hallazgo de seguridad más amplio que solo
     JotForm — se documentó en `INVENTORY.md` §4.2 sin abrir el contenido
     completo de cada `.env` (para no manejar más secretos de los
     imprescindibles).
8. Se extrajo la lista de ~30 form IDs de JotForm distintos referenciados en
   el código (`INVENTORY.md` §3) y se cruzó contra los 7 formularios que ya
   tiene cubiertos `credit-agents` — el resto (~25) son los candidatos a
   "bases de JotForm valiosas no reportadas" que pidió el usuario. No se
   consultó la API real de JotForm para confirmar actividad (`count`,
   `last_submission_time`) porque eso requiere usar la key ya filtrada, y se
   decidió no tocar/usar esa key hasta que se rote.
9. Se creó el hub en el repo `jotform` (antes vacío): `README.md`,
   `INVENTORY.md`, `roadmap.md`, `journal.md` (este archivo), y
   `docker-sandbox/` (Dockerfile + setup.sh + run-agent.sh + README, con
   placeholders donde no hay datos reales del servidor).

**Qué NO se hizo (a propósito):**
- No se modificó ningún archivo PHP/JS/Python existente en `vilarkptl`,
  `cPanel`, `ryby.lease`, `ryby-lease` ni `db-backups` — el usuario pidió
  solo documentar el hallazgo de la API key por ahora.
- No se llamó a la API real de JotForm con la key expuesta.
- No se abrió el contenido completo de los `.env` reales encontrados.
- No se intentó conectar a ningún servidor de staging ni correr Docker
  contra infraestructura real — no había acceso.
- No se tocó `db-backups` más allá de confirmar que no contiene las bases
  financieras reales del negocio.

**Para el siguiente agente:**
- Empieza por `roadmap.md` Fase 1 (remediación de secretos) — es bloqueante.
- Si vas a trabajar con acceso real a un servidor de staging, usa
  `docker-sandbox/README.md` de este repo, pero **reemplaza todos los
  placeholders** (`<SERVER_IP>`, `<AGENT_USER>`, etc.) con los valores reales
  antes de ejecutar nada, y nunca reutilices la API key de JotForm que ya
  está documentada como comprometida.
- Si el usuario ya rotó la key y quiere que se confirme actividad de los ~25
  formularios no cubiertos, esa es la siguiente pieza de trabajo concreta
  (Fase 2 del roadmap).

## Sesión 2026-07-02 (continuación, mismo día) — arranque de Fase 1

El usuario pidió empezar con el roadmap. Se preguntó estado de rotación de
la key de JotForm (respuesta: "aún no, la rotará él mismo después") y qué
tareas concretas de Fase 1 abordar hoy (respuesta: solo "refactorizar código
a variables de entorno").

**Hallazgo nuevo antes de tocar código:** al revisar los proxies backend se
encontraron **al menos 3 API keys de Anthropic (Claude) reales y distintas**
hardcodeadas en texto plano en
`cPanel/public_html/agata.financial/legal/LDOCR/proxy.php`, `proxy(2).php` y
`proxy3.php` (variable `$CLAUDE_KEY`), con riesgo de costo económico directo
(a diferencia de la key de JotForm, que es riesgo de integridad de datos).
Se preguntó al usuario qué hacer — respondió que ya las tiene identificadas
y que solo se documenten (no tocarlas), y que se continúe con el plan de
JotForm. Se agregó el detalle a `INVENTORY.md` §4.3 sin imprimir los valores
completos de las keys.

**Qué se hizo (refactor backend de JotForm a variable de entorno):**
Se reemplazó el literal `6e2676fa4067aecefdfae6fca7c4bb41` por
`getenv('JOTFORM_API_KEY') ?: ''` (PHP) o `os.getenv("JOTFORM_API_KEY", "")`
(Python) en 10 archivos:
- `vilarkptl/dashboard/api/config.php`
- `vilarkptl/dashboard/pages/jotform_submit.php`
- `cPanel/public_html/agata.financial/dashboard/api/config.php`
- `cPanel/public_html/vilarkptl.com/dashboard/api/config.php`
- `cPanel/public_html/kptl.mx/dashboard/api2/config.php`
- `cPanel/public_html/vilarkptl.com/dashboard/pages/jotform_submit.php`
- `cPanel/public_html/agata.financial/legal/LDOCR/proxy.php` (solo la línea
  `$JF_KEY`, no se tocó `$CLAUDE_KEY`)
- `cPanel/public_html/agata.financial/legal/LDOCR/proxy(2).php` (ídem)
- `cPanel/public_html/agata.financial/legal/LDOCR/proxy3.php` (ídem)
- `ryby.lease/html/credit-agents/api/scripts/migrate_jotform.py` (se quitó
  el fallback hardcodeado del `os.getenv(...)`)

**Decisiones de alcance tomadas sin preguntar de nuevo (consistentes con lo
ya acordado):**
- No se tocaron los duplicados en `ryby.lease/html/vilarkptl.com/**` ni
  `ryby.lease/html/cpanel-repo/**` — son snapshots viejos, no aportan
  seguridad real y hubieran inflado el diff.
- No se tocó `ryby.lease/html/credit-agents-testing/` (variante de pruebas).
- No se tocaron los ~187 archivos **frontend** (`.js` servidos al
  navegador) que tienen la misma key embebida como `const apiKey = '...'` —
  este descubrimiento es más grande de lo estimado en la sesión anterior
  (se pensaba que eran ~8 archivos; son ~41 en `vilarkptl` + ~146 en
  `cPanel/public_html`). No es un fix de "variable de entorno" (el navegador
  no tiene env vars) — requiere decidir arquitectura (pasar por el proxy
  existente vs. quitar la llamada directa). Documentado en `INVENTORY.md`
  §4.1 y añadido como pendiente explícito en `roadmap.md` Fase 1.

**Importante — esto NO rota la key.** El código ya no tiene el valor
escrito, pero sigue siendo la misma key comprometida hasta que el usuario la
rote en JotForm. El servidor real necesitará que alguien exporte
`JOTFORM_API_KEY` como variable de entorno (Apache `SetEnv`, `.htaccess`, o
el `.env` de `credit-agents`) para que estos 10 archivos sigan funcionando.

**Para el siguiente agente:** el pendiente más grande de Fase 1 es decidir
qué hacer con los ~187 archivos frontend. No asumir que "variable de
entorno" aplica ahí — hay que proponer una arquitectura (probablemente
enrutar todo a través de `jotform-proxy.php`, que ya soporta `formID`/
`submissionID`) y confirmar con el usuario antes de tocar esos archivos,
porque cambia el comportamiento real de páginas en producción.
