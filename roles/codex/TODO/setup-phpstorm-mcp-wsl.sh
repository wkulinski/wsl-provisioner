#!/usr/bin/env bash
set -euo pipefail

# --- CONFIG (łatwe do automatyzacji / zmiany) ---
SERVER_NAME="phpstorm"
WIN_CMD="C:\\Users\\wojci\\bin\\phpstorm-mcp.cmd"

CODEX_DIR="${HOME}/.codex"
CODEX_CFG="${CODEX_DIR}/config.toml"

mkdir -p "${CODEX_DIR}"

# Minimalny, jednoznaczny blok TOML.
read -r -d '' BLOCK <<EOF || true

[mcp_servers.${SERVER_NAME}]
command = "/mnt/c/Windows/System32/cmd.exe"
args = ["/c", "${WIN_CMD}"]
startup_timeout_sec = 30
tool_timeout_sec = 120
EOF

# Idempotent: jeśli blok już istnieje -> nie dopisujemy drugi raz.
if [[ -f "${CODEX_CFG}" ]] && grep -q "^\[mcp_servers\.${SERVER_NAME}\]$" "${CODEX_CFG}"; then
  echo "[INFO] ${CODEX_CFG} already contains [mcp_servers.${SERVER_NAME}] - no changes."
else
  echo "[INFO] Adding MCP server '${SERVER_NAME}' to ${CODEX_CFG}"
  printf "%s\n" "${BLOCK}" >> "${CODEX_CFG}"
fi

# Szybkie sanity checks
if [[ ! -f "/mnt/c/Users/wojci/bin/phpstorm-mcp.cmd" ]]; then
  echo "[WARN] Missing Windows CMD wrapper: /mnt/c/Users/wojci/bin/phpstorm-mcp.cmd"
  echo "[WARN] Run the Windows PowerShell script first: setup-phpstorm-mcp-windows.ps1"
fi

echo "[INFO] Done."
echo "[INFO] Next: start PhpStorm (MCP Server enabled), then start codex and run /mcp to verify tools."
