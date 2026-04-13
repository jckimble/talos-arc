#!/usr/bin/env bash
set -euo pipefail

TALHELPER_VERSION="${VERSION:-v3.1.7}"
ARCH="$(uname -m)"
case "${ARCH}" in
  x86_64) TALHELPER_ARCH="amd64" ;;
  aarch64|arm64) TALHELPER_ARCH="arm64" ;;
  *)
    echo "Unsupported architecture for talhelper: ${ARCH}" >&2
    exit 1
    ;;
esac

if [[ "${TALHELPER_VERSION}" == "latest" ]]; then
  TALHELPER_VERSION="$(curl -fsSL https://api.github.com/repos/budimanjojo/talhelper/releases/latest | sed -n 's/.*"tag_name": "\([^"]*\)".*/\1/p' | head -n 1)"
fi

if [[ -z "${TALHELPER_VERSION}" ]]; then
  echo "Failed to resolve talhelper version" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

echo "Installing talhelper ${TALHELPER_VERSION} (${TALHELPER_ARCH})"
downloaded=false
for TAR_NAME in \
  "talhelper_linux_${TALHELPER_ARCH}.tar.gz" \
  "talhelper_${TALHELPER_VERSION#v}_linux_${TALHELPER_ARCH}.tar.gz"
do
  URL="https://github.com/budimanjojo/talhelper/releases/download/${TALHELPER_VERSION}/${TAR_NAME}"
  rm -f "${TMP_DIR}/talhelper.tar.gz"
  if curl -fsSL "${URL}" -o "${TMP_DIR}/talhelper.tar.gz"; then
    downloaded=true
    break
  fi
done

if [[ "${downloaded}" != true ]]; then
  echo "Unable to download talhelper ${TALHELPER_VERSION} for ${TALHELPER_ARCH}" >&2
  exit 1
fi

tar -xzf "${TMP_DIR}/talhelper.tar.gz" -C "${TMP_DIR}"
install -m 0755 "${TMP_DIR}/talhelper" /usr/local/bin/talhelper

/usr/local/bin/talhelper --version
