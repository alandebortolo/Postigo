#!/bin/bash
# Postigo — cola esta linha no Terminal e aperta Enter:
#   curl -fsSL https://raw.githubusercontent.com/alandebortolo/Postigo/main/install.sh | bash
set -euo pipefail

REPO="alandebortolo/Postigo"
DEST="${HOME}/Applications"
APP="${DEST}/Postigo.app"
ZIP_URL="https://github.com/${REPO}/releases/latest/download/Postigo.zip"

say() { printf '%s\n' "$*"; }
die() { printf '%s\n' "$*" >&2; exit 1; }

if [[ "$(uname -s)" != "Darwin" ]]; then
  die "Postigo é um app de Mac. Este computador não é um Mac."
fi

os_major="$(sw_vers -productVersion | cut -d. -f1)"
if [[ "${os_major}" -lt 14 ]]; then
  die "Postigo precisa de macOS 14 ou mais novo. Este Mac está no $(sw_vers -productVersion)."
fi

arch="$(uname -m)"
if [[ "${arch}" != "arm64" ]]; then
  die "Este instalador é para Mac com chip da Apple (M1, M2, M3, M4). O seu é ${arch}."
fi

say "Postigo vai para ${APP}"
mkdir -p "${DEST}"

tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

src=""
root=""
if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
  root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
if [[ -n "${root}" && -d "${root}/dist/Postigo.app" ]]; then
  src="${root}/dist/Postigo.app"
  say "Usando o app que já está neste repositório."
else
  say "Baixando a última versão…"
  if ! curl -fL --retry 3 --retry-delay 2 -o "${tmp}/Postigo.zip" "${ZIP_URL}"; then
    die "Não deu para baixar.
Abre no navegador e baixa na mão:
${ZIP_URL}"
  fi
  ditto -xk "${tmp}/Postigo.zip" "${tmp}/out"
  src="$(find "${tmp}/out" -name 'Postigo.app' -type d -print -quit || true)"
  [[ -n "${src}" ]] || die "O arquivo baixado não tinha o Postigo.app. Tenta de novo daqui a um minuto."
fi

killall Postigo 2>/dev/null || true
killall DeskCam 2>/dev/null || true
sleep 0.3

rm -rf "${APP}"
ditto "${src}" "${APP}"
xattr -cr "${APP}" 2>/dev/null || true
codesign --force --sign - --identifier br.com.designmaster.deskcam "${APP}" >/dev/null 2>&1 || true

[[ -x "${APP}/Contents/MacOS/Postigo" ]] || die "A cópia falhou. ${APP} não é executável."

open "${APP}"

say ""
say "Pronto. Olha a barra de menu, em cima à direita: uma portinhola."
say "Se o Mac recusar o app: Ajustes > Privacidade e segurança > Abrir mesmo assim."
say "No primeiro Gravar ou Preferências, deixa a Câmera."
