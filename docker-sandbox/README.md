# Docker Sandbox — Guía para Agentes Claude Code (proyecto Jotform ↔ Vilar KPTL)

> Adaptado de la guía compartida por el usuario. Los valores entre `<...>`
> son placeholders: **nadie ha reemplazado estos valores con datos reales
> todavía**, y ningún comando de este documento se ejecutó en la sesión que
> lo generó (2026-07-02) — esa sesión solo tenía acceso a los repos de
> GitHub, no a un servidor real.

Cualquier agente que opere sobre estos 6 repos con acceso a un servidor real
**debe** correr dentro del contenedor Docker descrito aquí. Nunca ejecutar
`claude` directamente en el host del servidor de staging/producción.

## Arquitectura de seguridad

```
┌─────────────────────────────────────────────────────────────────┐
│  Servidor de staging                                             │
│  IP pública: <SERVER_IP>  |  IP VPN: <VPN_IP>                    │
│  Usuario del agente: <AGENT_USER>                                 │
│                                                                   │
│  ┌────────────────────────────────────────────────────────┐      │
│  │  Docker container (imagen: jotform-agent-sandbox)       │      │
│  │                                                          │      │
│  │  • Claude Code CLI (usuario no-root dentro)              │      │
│  │  • GITHUB_TOKEN → scoped solo a los repos de este proyecto│     │
│  │  • INFISICAL → secretos de negocio (JOTFORM_API_KEY nueva,│     │
│  │    credenciales MySQL de staging, nunca las de prod)      │      │
│  │  • ~/.claude montado :ro → auth de Claude heredada        │      │
│  │  • Sin tokens de Cloudflare, AWS, ni infra de prod         │      │
│  └────────────────────────────────────────────────────────┘      │
│                                                                   │
│  GitHub Actions (corre en la nube, separado del servidor)         │
│  • Credenciales de deploy (si existen)                            │
│  • Solo se activa por push al repo — el agente nunca lo ve         │
└─────────────────────────────────────────────────────────────────┘
```

**Reglas absolutas:**
- La API key de JotForm usada aquí **debe ser una key nueva, rotada**
  después del incidente documentado en `../INVENTORY.md` §4.1. Nunca
  reutilizar `6e2676fa... (REDACTADO 2026-07-22 -- valor completo removido de este repo publico, ver Cyber-Brain para el hallazgo)`.
- Tokens de deploy (Cloudflare, AWS, etc.) **nunca** entran al sandbox.
- El sandbox solo tiene un PAT de GitHub scoped a los repos de este proyecto.
- Secretos de negocio → vía Infisical, nunca hardcodeados (ver
  `../INVENTORY.md` §4.2 para la lista de `.env` reales que deben migrarse
  a Infisical y eliminarse del repo).
- El agente hace push → CI/CD hace el deploy automáticamente (si aplica).

## Conexión al servidor

Rellenar `<VPN_IP>`, `<SERVER_IP>`, `<AGENT_USER>` con los datos reales del
servidor de staging antes de usar cualquiera de estas opciones. Ninguno de
estos hosts es conocido por el hub de este repo.

### Opción A — Mosh (recomendado para conexiones VPN/móviles)

```
Host:    <VPN_IP>  ó  <SERVER_IP>
Usuario: <AGENT_USER>
Auth:    llave SSH
Método:  Mosh (requiere UDP 60000-61000 abierto en el firewall)
```

Instalar mosh en el servidor (una sola vez):
```bash
apt-get install -y mosh
ufw allow 60000:61000/udp
```

### Opción B — SSH directo

```bash
ssh <AGENT_USER>@<VPN_IP>
# ó por IP pública si no hay VPN:
ssh <AGENT_USER>@<SERVER_IP>
```

## Setup inicial (una sola vez por servidor)

```bash
# ── Como root ─────────────────────────────────────────────────────────────
id <AGENT_USER> &>/dev/null || useradd -m -s /bin/bash <AGENT_USER>
usermod -aG docker <AGENT_USER>

grep -q "^ClientAliveInterval" /etc/ssh/sshd_config || {
  echo "ClientAliveInterval 30" >> /etc/ssh/sshd_config
  echo "ClientAliveCountMax 10" >> /etc/ssh/sshd_config
  systemctl reload sshd
}

# Clonar los 6 repos del proyecto (fine-grained PAT scoped solo a estos repos)
export GITHUB_TOKEN="<GITHUB_TOKEN_SCOPED_A_ESTOS_6_REPOS>"
for REPO in jotform cPanel ryby.lease ryby-lease vilarkptl db-backups; do
  git clone "https://x-access-token:${GITHUB_TOKEN}@github.com/vilarkptl-lang/${REPO}.git" \
      --branch claude/jotform-docker-sandbox-setup-wkulto --depth 1 \
      "/opt/jotform-sandbox/${REPO}"
done

bash /opt/jotform-sandbox/jotform/docker-sandbox/setup.sh
docker build -t jotform-agent-sandbox /opt/jotform-sandbox/jotform/docker-sandbox/

# ── Como <AGENT_USER> ────────────────────────────────────────────────────
su - <AGENT_USER>
claude auth login
chmod 644 ~/.claude.json
chmod -R o+rX ~/.claude/
```

## Ejecutar el agente

```bash
su - <AGENT_USER>

export GITHUB_TOKEN="<GITHUB_TOKEN_SCOPED_A_ESTOS_6_REPOS>"
# Solo si la tarea necesita secretos de negocio (JotForm key rotada, MySQL de staging):
export INFISICAL_CLIENT_ID="<...>"
export INFISICAL_CLIENT_SECRET="<...>"

bash /opt/jotform-sandbox/jotform/docker-sandbox/run-agent.sh "Descripción de la tarea"

tmux attach -t jotform-agent   # ver en vivo
# Ctrl+B, D para detach sin matar el agente
```

## Secretos y autenticación

### Claude Code
Se montan `~/.claude/` y `~/.claude.json` del `<AGENT_USER>` del host como
`:ro`. El contenedor hereda el OAuth/proxy configurado. No se necesita
`ANTHROPIC_API_KEY`.

### GitHub PAT

| Campo | Valor |
|---|---|
| Tipo | Fine-grained PAT |
| Scope | Solo los 6 repos de este proyecto |
| Permisos | `Contents: Read/Write` + `Metadata: Read` |
| Vigencia | 90 días máximo |

### Infisical — secretos de negocio del proyecto Jotform

```bash
# Fetchear la key de JotForm ya rotada (nunca la vieja)
infisical secrets get JOTFORM_API_KEY --env=staging

# Credenciales MySQL de staging para credit-agents
infisical secrets get DB_HOST --env=staging
infisical secrets get DB_USER --env=staging
infisical secrets get DB_PASS --env=staging
infisical secrets get DB_NAME --env=staging
```

### Tokens de deploy
**Nunca entran al sandbox.** Viven solo en
`GitHub → Settings → Secrets and variables → Actions`.

## Patrones de uso

```bash
# Desarrollo estándar
export GITHUB_TOKEN="..."
bash docker-sandbox/run-agent.sh "Recrea el monolito de crédito en TypeScript"

# Con secretos de negocio (p.ej. correr migrate_jotform.py contra staging)
export GITHUB_TOKEN="..."
export INFISICAL_CLIENT_ID="..."
export INFISICAL_CLIENT_SECRET="..."
bash docker-sandbox/run-agent.sh "Corre migrate_jotform.py --dry-run contra la DB de staging y reporta el diff"

# Verificar estado
tmux ls
docker ps --filter "name=jotform-agent"
docker logs jotform-agent

# Matar y relanzar
tmux kill-session -t jotform-agent
docker stop jotform-agent 2>/dev/null || true
bash docker-sandbox/run-agent.sh "Nueva tarea"

# Reconstruir imagen tras cambios en Dockerfile
docker build -t jotform-agent-sandbox /opt/jotform-sandbox/jotform/docker-sandbox/

# Debug interactivo
docker run --rm -it \
  -v /home/<AGENT_USER>/.claude:/home/agent/.claude:ro \
  -v /home/<AGENT_USER>/.claude.json:/home/agent/.claude.json:ro \
  jotform-agent-sandbox \
  claude auth status
```

## Límites del contenedor

| Recurso | Valor por defecto | Configurable en |
|---|---|---|
| RAM | 1 GB | `run-agent.sh` → `--memory` |
| CPU | 1.5 cores | `run-agent.sh` → `--cpus` |
| Red | Host networking | `run-agent.sh` → `--network` |
| Turnos máximos | 40 | `run-agent.sh` → `--max-turns` |
| Filesystem | Solo los repos clonados en `/opt/jotform-sandbox` | Volúmenes Docker |

## Qué puede y no puede hacer el agente

| Permitido | Prohibido |
|---|---|
| Editar archivos de los 6 repos clonados | Escribir fuera de `/home/agent/project` |
| `git commit` y `git push` a los repos scoped | Acceder a otros repos de la org |
| Leer secretos vía Infisical (proyecto Jotform) | Tokens de deploy de producción |
| Requests HTTP a `api.jotform.com` y a la DB de staging | Modificar credenciales del host |
| Leer `~/.claude` (read-only) | Correr como root dentro del contenedor |
| Conectarse a la DB de **staging** de `credit-agents` | Conectarse a la DB de **producción** sin autorización explícita del dueño del negocio |

## Troubleshooting

| Síntoma | Causa | Fix |
|---|---|---|
| `Not logged in` | `.claude.json` no legible por el contenedor | `chmod 644 ~/.claude.json && chmod -R o+rX ~/.claude/` |
| `[exited]` inmediato en tmux | Auth falla o crash en inicio | `docker run --rm -it jotform-agent-sandbox claude auth status` |
| `Permission denied` en git pull | Repo clonado por otro usuario | `sudo git pull` o clonar con el usuario correcto |
| Imagen no encontrada | No se construyó | `docker build -t jotform-agent-sandbox /opt/jotform-sandbox/jotform/docker-sandbox/` |
| SSH se desconecta | Timeout de VPN | Mosh + `ClientAliveInterval 30` |
