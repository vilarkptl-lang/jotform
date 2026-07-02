# Sandbox para agentes Claude Code — proyecto Jotform ↔ Vilar KPTL
# Imagen mínima: git + Node (Claude Code CLI) + Python (para credit-agents/migrate_jotform.py)
FROM node:20-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        curl \
        ca-certificates \
        python3 \
        python3-pip \
        default-mysql-client \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g @anthropic-ai/claude-code

# Usuario no-root
RUN useradd -m -s /bin/bash agent
USER agent
WORKDIR /home/agent/project

# Dependencias Python usadas por credit-agents/api (mysql-connector, requests, flask...)
COPY --chown=agent:agent requirements-sandbox.txt /home/agent/requirements-sandbox.txt
RUN pip3 install --user --no-cache-dir -r /home/agent/requirements-sandbox.txt || true

ENTRYPOINT ["/bin/bash"]
