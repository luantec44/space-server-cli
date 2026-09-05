#!/usr/bin/env bash
set -Eeuo pipefail
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

OWNER="luantec44"
REPO="space-server-cli"
BRANCH="main"
BASE="https://raw.githubusercontent.com/${OWNER}/${REPO}/${BRANCH}"
VERSION="1.9.12"

[[ "${EUID:-$(id -u)}" -eq 0 ]] || { echo 'ERRO: execute como root.'; exit 1; }
command -v curl >/dev/null 2>&1 || { apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq curl ca-certificates; }

case "$(uname -m)" in
  x86_64|amd64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) echo "ERRO: arquitetura não suportada: $(uname -m)."; exit 1 ;;
esac

BIN="bin/sshplus-installer-linux-${ARCH}"
TMP="$(mktemp /tmp/sshplus-installer.XXXXXX)"
SUMS="$(mktemp /tmp/sshplus-sums.XXXXXX)"
cleanup(){ rm -f "$TMP" "$SUMS"; }
trap cleanup EXIT

echo "Baixando SSHPLUS SPACE PRO v${VERSION} (${ARCH})..."
curl -fL --retry 4 --retry-delay 2 --connect-timeout 15 "${BASE}/${BIN}" -o "$TMP"
curl -fsSL --retry 3 "${BASE}/SHA256SUMS" -o "$SUMS"
EXPECTED="$(awk -v f="$BIN" '$2==f{print $1}' "$SUMS" | head -n1)"
[[ -n "$EXPECTED" ]] || { echo 'ERRO: checksum esperado não encontrado.'; exit 1; }
ACTUAL="$(sha256sum "$TMP" | awk '{print $1}')"
[[ "$ACTUAL" == "$EXPECTED" ]] || { echo 'ERRO: SHA-256 inválido. Instalação cancelada.'; exit 1; }
chmod 700 "$TMP"
exec "$TMP"
