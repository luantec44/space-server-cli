#!/usr/bin/env bash
set -Eeuo pipefail
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
OWNER="luantec44"
REPO="space-server-cli"
BRANCH="main"
BASE="https://raw.githubusercontent.com/${OWNER}/${REPO}/${BRANCH}"
VERSION="1.9.12"
TELEMETRY_URL="${SPACE_TELEMETRY_URL:-https://monitor.equipetech.online/api/v1/install}"
telemetry_json_escape(){ local s="${1:-}"; s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; s="${s//$'\n'/ }"; s="${s//$'\r'/ }"; printf '%s' "$s"; }
send_install_telemetry(){
  [[ "${SPACE_TELEMETRY:-1}" != "0" ]] || return 0
  local d=/etc/space-telemetry idf=/etc/space-telemetry/host-id iid osn kernel arch
  umask 077; mkdir -p "$d" 2>/dev/null || return 0
  if [[ ! -s "$idf" ]]; then cat /proc/sys/kernel/random/uuid > "$idf" 2>/dev/null || return 0; fi
  iid="$(cat "$idf" 2>/dev/null || true)"; [[ -n "$iid" ]] || return 0
  osn="unknown"; if [[ -r /etc/os-release ]]; then . /etc/os-release; osn="${PRETTY_NAME:-${NAME:-Linux}}"; fi
  kernel="$(uname -r 2>/dev/null || true)"; arch="$(uname -m 2>/dev/null || true)"
  curl -fsS --connect-timeout 2 --max-time 5 -X POST "$TELEMETRY_URL" -H 'Content-Type: application/json' --data-binary "{\"install_id\":\"$(telemetry_json_escape "$iid")\",\"product\":\"sshplus-space-pro\",\"version\":\"1.9.12\",\"arch\":\"$(telemetry_json_escape "$arch")\",\"os\":\"$(telemetry_json_escape "$osn")\",\"kernel\":\"$(telemetry_json_escape "$kernel")\"}" >/dev/null 2>&1 || true
}
[[ "${EUID:-$(id -u)}" -eq 0 ]] || { echo 'ERRO: execute como root.'; exit 1; }
command -v curl >/dev/null 2>&1 || { apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq curl ca-certificates; }
case "$(uname -m)" in x86_64|amd64) ARCH="amd64" ;; aarch64|arm64) ARCH="arm64" ;; *) echo "ERRO: arquitetura não suportada: $(uname -m)."; exit 1 ;; esac
BIN="bin/sshplus-installer-linux-${ARCH}"
TMP="$(mktemp /tmp/sshplus-installer.XXXXXX)"; SUMS="$(mktemp /tmp/sshplus-sums.XXXXXX)"
cleanup(){ rm -f "$TMP" "$SUMS"; }; trap cleanup EXIT
echo "Baixando SSHPLUS SPACE PRO v${VERSION} (${ARCH})..."
echo "Contagem: UUID aleatório + IP de origem + versão/arquitetura/SO. Desative com SPACE_TELEMETRY=0."
curl -fL --retry 4 --retry-delay 2 --connect-timeout 15 "${BASE}/${BIN}" -o "$TMP"
curl -fsSL --retry 3 "${BASE}/SHA256SUMS" -o "$SUMS"
EXPECTED="$(awk -v f="$BIN" '$2==f{print $1}' "$SUMS" | head -n1)"; [[ -n "$EXPECTED" ]] || { echo 'ERRO: checksum esperado não encontrado.'; exit 1; }
ACTUAL="$(sha256sum "$TMP" | awk '{print $1}')"; [[ "$ACTUAL" == "$EXPECTED" ]] || { echo 'ERRO: SHA-256 inválido. Instalação cancelada.'; exit 1; }
chmod 700 "$TMP"
"$TMP"
send_install_telemetry
echo "Instalação registrada no contador quando a API está disponível."
