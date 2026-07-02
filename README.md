# jotform — Hub del proyecto "Jotform ↔ Vilar KPTL"

Este repo estaba vacío y se usa como **hub central** de un esfuerzo multi-sesión que
cruza 6 repositorios de la organización (`jotform`, `cPanel`, `ryby.lease`,
`ryby-lease`, `vilarkptl`, `db-backups`) para:

1. Mapear todas las conexiones existentes entre los sitios/monolitos HTML de
   Vilar KPTL y JotForm (JS de envío + proxies PHP/Python).
2. Detectar qué bases de datos de JotForm tienen valor y actividad real, pero
   no están siendo reportadas/visualizadas en ningún dashboard actual.
3. Recrear los monolitos HTML relevantes con un stack TypeScript.
4. Dejar preparado (no ejecutado) un sandbox Docker para que un agente con
   acceso real a un servidor de staging pueda continuar el trabajo de forma
   segura.

Lee primero:
- [`roadmap.md`](./roadmap.md) — plan por fases, qué falta y por qué.
- [`journal.md`](./journal.md) — bitácora de cada sesión, para el siguiente agente en turno.
- [`INVENTORY.md`](./INVENTORY.md) — inventario detallado de todo lo encontrado en los 6 repos.
- [`docker-sandbox/`](./docker-sandbox/) — scaffold del sandbox Docker (sin credenciales reales).

## Alcance real de este repo

Este hub **no tiene acceso** a ningún servidor de staging, Docker daemon
externo, ni a Infisical/Cloudflare. Todo lo que hay aquí es código y
documentación preparados para que un humano o un agente con acceso SSH real
al servidor los ejecute. Ningún comando de este repo se ha corrido contra
infraestructura de producción.

## ⚠️ Antes de tocar nada: secretos expuestos

Ver la sección "Hallazgos de seguridad" en `roadmap.md`. Hay una API key de
JotForm y decenas de archivos `.env` reales (no `.env.example`) committeados
en `ryby.lease`. Rotar credenciales es una acción que solo el dueño del
negocio puede hacer — este hub la documenta pero no la ejecuta.
