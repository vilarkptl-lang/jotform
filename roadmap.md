# Roadmap — Jotform ↔ Vilar KPTL (docker sandbox + monolitos TypeScript)

> Lee `INVENTORY.md` primero — este roadmap asume ese contexto.

## Resumen para quien llegue sin contexto

El pedido original: usar un sandbox Docker para conectar un agente de forma
segura, explorar los 6 repos de la org, encontrar todas las conexiones a
JotForm, "levantar" en un servidor de staging las bases de datos del negocio,
y recrear los monolitos HTML en TypeScript — dando prioridad a formularios de
JotForm con actividad real que hoy no se visualizan en ningún lado.

Esta sesión (2026-07-02) **no tuvo acceso** a ningún servidor de staging,
Docker daemon externo, ni credenciales de Infisical/JotForm reales — solo a
los 6 repos de GitHub, clonados localmente en un contenedor efímero. Por eso
esta sesión se limitó a: reconocimiento completo, documentación, y scaffold
de herramientas — sin ejecutar nada contra infraestructura real.

## Fase 0 — Reconocimiento (✅ completada esta sesión)

- [x] Mapear los 6 repos y detectar duplicación entre ellos.
- [x] Encontrar todos los puntos de integración con JotForm (JS + PHP + Python).
- [x] Descubrir que ya existe un sistema funcional (`credit-agents` en
      `ryby.lease/html/credit-agents/`) que migra JotForm → MySQL.
- [x] Confirmar que no existe TypeScript en ningún repo.
- [x] Detectar y documentar (sin explotar) la API key de JotForm expuesta y
      los `.env` reales committeados.

## Fase 1 — Remediación de secretos (bloqueante, requiere al dueño del negocio)

**No se puede avanzar de forma responsable a Fase 2/3 sin esto**, porque
cualquier sandbox o staging que se conecte a JotForm seguiría usando una key
ya filtrada.

- [ ] Rotar la API key de JotForm (`6e2676fa4067aecefdfae6fca7c4bb41`) desde
      el dashboard de JotForm. Solo el dueño de la cuenta puede hacerlo.
      **Confirmado 2026-07-02: el usuario la rotará él mismo, pendiente.**
- [ ] Rotar las ≥3 API keys de Anthropic hardcodeadas en
      `agata.financial/legal/LDOCR/proxy*.php` (ver `INVENTORY.md` §4.3).
      **El usuario confirmó 2026-07-02 que ya las tiene identificadas y las
      rota por su cuenta.**
- [x] Refactorizar el **backend** (PHP/Python) para leer la key de JotForm
      de variable de entorno en vez de tenerla hardcodeada — hecho
      2026-07-02 en 10 archivos (ver `INVENTORY.md` §4.1). **Esto no rota la
      key**, solo saca el valor del código fuente; el servidor deberá
      exportar `JOTFORM_API_KEY` para que estos archivos sigan funcionando
      una vez que se rote.
- [ ] Reescribir los ~187 archivos **frontend** (JS servido al navegador) que
      tienen la key embebida directamente (`const apiKey = '...'`). Esto es
      más grande de lo estimado inicialmente y no es un simple cambio a
      variable de entorno (el navegador no tiene acceso a env vars) — requiere
      decidir si se reescriben para pasar por el proxy backend existente
      (`jotform-proxy.php`) o se elimina el llamado directo a JotForm desde el
      cliente. Ver `INVENTORY.md` §4.1 para la lista completa.
- [ ] Auditar cada `.env` real listado en `INVENTORY.md` §4.2: qué
      credenciales contiene, si siguen vigentes, rotarlas.
- [ ] Decidir estrategia para el historial de git de `ryby.lease` (los
      secretos viejos siguen en los commits aunque se borren los archivos):
      reescribir historial vs. archivar el repo y empezar uno limpio.
- [ ] Añadir `.env`, `.env.*` (excepto `.env.example`) a `.gitignore` en los
      6 repos.

## Fase 2 — Confirmar y consolidar el sistema `credit-agents`

Antes de construir nada nuevo, hay que entender si esto ya está vivo:

- [ ] ¿Este Flask+MySQL corre hoy en algún servidor? ¿Dónde? (buscar
      `.htaccess`, configs de Apache/WSGI dentro de `credit-agents/apache/`).
- [ ] ¿Las migraciones (`001`…`011`) ya se corrieron contra una base real, o
      solo existen como archivos `.sql` sin aplicar?
- [ ] Comparar la lista `FORMS` de `migrate_jotform.py` (5 formularios) y
      `FORM_PF`/`FORM_PM` de `migrate_solicitudes_jotform.py` (2 formularios)
      contra los ~30 IDs de formulario detectados en `INVENTORY.md` §3. Los
      que **no** están cubiertos son los candidatos directos a "bases de
      JotForm valiosas no reportadas" que pidió el negocio.
- [ ] Para cada formulario no cubierto: `GET https://api.jotform.com/form/{id}`
      (requiere la key ya rotada) da `count` y `last_submission_time` — así
      se prioriza por actividad real, no por suposición.

## Fase 3 — Monolitos en TypeScript

Trabajo nuevo, no migración (no había TS previo). Sugerido, a validar con el
negocio:
- [ ] Elegir 1 monolito piloto (candidato: `credito` o `arrendamiento`, son
      los que tienen más módulos JS/PHP alrededor) y recrearlo como proyecto
      TypeScript aislado (Vite + TS, sin framework pesado) que:
      reemplace `jotform.js`/`linkJotform.js`/`sendtable.js` por un cliente
      tipado que hable con el proxy PHP existente (o con `services/jotform.py`
      si se decide migrar el proxy también a `credit-agents`).
- [ ] Definir tipos TS para las respuestas de JotForm (`submission`, `answer`,
      `question`) reutilizables entre monolitos.
- [ ] Solo después de validar el piloto, replicar al resto de los ~15 módulos.

## Fase 4 — Staging real (requiere acceso humano/servidor)

Esto es lo que la guía de `docker-sandbox/` (en este repo) describe, pero
**ningún paso de esta fase se ejecutó en esta sesión** por falta de acceso:
- [ ] Un humano o agente con SSH real completa el "Setup inicial" de
      `docker-sandbox/README.md` en el servidor de staging real.
- [ ] Desplegar `credit-agents` (o su reemplazo) apuntando a una base MySQL de
      staging, nunca a la de producción.
- [ ] Correr `migrate_jotform.py --dry-run` primero, revisar el diff, luego
      sin `--dry-run`.
- [ ] Conectar los monolitos TypeScript piloto contra ese staging.

## Hallazgos de seguridad — ver `INVENTORY.md` §4

No repetidos aquí para evitar que se desactualicen en dos lugares. Cualquier
sesión futura debe releer esa sección antes de tocar código de producción.
