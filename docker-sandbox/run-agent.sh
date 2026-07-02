#!/usr/bin/env bash
# Lanza un agente Claude Code dentro del sandbox Docker, en una sesión tmux.
# Placeholder: nadie ha corrido esto todavía (sesión 2026-07-02 no tuvo acceso a servidor).
#
# Uso:
#   export GITHUB_TOKEN="..."
#   [export INFISICAL_CLIENT_ID="..." INFISICAL_CLIENT_SECRET="..."]
#   bash run-agent.sh "Descripción de la tarea"
set -euo pipefail

TASK="${1:?Uso: run-agent.sh \"descripción de la tarea\"}"
IMAGE_NAME="jotform-agent-sandbox"
SESSION_NAME="jotform-agent"
PROJECT_DIR="/opt/jotform-sandbox"     # ajustar si los repos viven en otra ruta
AGENT_HOME="${HOME}"

: "${GITHUB_TOKEN:?Falta GITHUB_TOKEN scoped a los repos del proyecto}"

if [ ! -d "${PROJECT_DIR}" ]; then
    echo "No existe ${PROJECT_DIR}. Clona los 6 repos ahí primero (ver docker-sandbox/README.md)." >&2
    exit 1
fi

ENV_ARGS=(-e GITHUB_TOKEN="${GITHUB_TOKEN}")
if [ -n "${INFISICAL_CLIENT_ID:-}" ] && [ -n "${INFISICAL_CLIENT_SECRET:-}" ]; then
    ENV_ARGS+=(-e INFISICAL_CLIENT_ID="${INFISICAL_CLIENT_ID}")
    ENV_ARGS+=(-e INFISICAL_CLIENT_SECRET="${INFISICAL_CLIENT_SECRET}")
fi

DOCKER_CMD=(docker run --rm -it \
    --name "${SESSION_NAME}" \
    --memory=1g --cpus=1.5 \
    --network host \
    -v "${AGENT_HOME}/.claude:/home/agent/.claude:ro" \
    -v "${AGENT_HOME}/.claude.json:/home/agent/.claude.json:ro" \
    -v "${PROJECT_DIR}:/home/agent/project" \
    "${ENV_ARGS[@]}" \
    "${IMAGE_NAME}" \
    -lc "cd /home/agent/project && claude --max-turns 40 -p \"${TASK}\"")

echo "Lanzando agente en tmux (sesión: ${SESSION_NAME}) ..."
tmux new-session -d -s "${SESSION_NAME}" "${DOCKER_CMD[@]}"

echo "Agente lanzado. Adjuntarse con: tmux attach -t ${SESSION_NAME}"
echo "Detach sin matar el agente: Ctrl+B, D"
