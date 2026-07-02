#!/usr/bin/env bash
# Setup inicial del sandbox en el servidor de staging real.
# Placeholder: nadie ha corrido esto todavía (sesión 2026-07-02 no tuvo acceso a servidor).
#
# Requiere correrse como root, con Docker ya instalado en el host.
set -euo pipefail

IMAGE_NAME="jotform-agent-sandbox"
SANDBOX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v docker >/dev/null 2>&1; then
    echo "Docker no está instalado en este host. Instálalo antes de continuar." >&2
    exit 1
fi

echo "Construyendo imagen ${IMAGE_NAME} desde ${SANDBOX_DIR} ..."
docker build -t "${IMAGE_NAME}" "${SANDBOX_DIR}"

echo "Listo. Usa run-agent.sh para lanzar el agente dentro de tmux."
