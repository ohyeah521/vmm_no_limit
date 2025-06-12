#!/usr/bin/env bash
#
# Copyright (C) 2025 ohyeah521 <https://github.com/ohyeah521>
#
# This is free software, licensed under the GPLv3 License.
# See /LICENSE for more information.
#

WORK_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

install() {
  _get_files() {
    local url="${1}" file="${2}"
    mkdir -p "$(dirname "${file}" 2>/dev/null)" 2>/dev/null
    STATUS="$(curl -skL ${CPROXY:+-x ${CPROXY}} -w "%{http_code}" "${url}" -o "${file}")"
    STATUS="${STATUS: -3}"
    case "${STATUS}" in
    "000")
      rm -f "${file}"
      echo "Error: ${STATUS}, Failed to connect to GitHub. Please check your network and try again."
      return 1
      ;;
    "200")
      echo "Info: $(basename "${url}" 2>/dev/null) downloaded successfully."
      return 0
      ;;
    "403")
      rm -f "${file}"
      echo "Error: ${STATUS}, Access forbidden to the package on GitHub."
      return 1
      ;;
    "404")
      rm -f "${file}"
      echo "Warning: $(basename "${url}" 2>/dev/null) skipped, not exist."
      return 0
      ;;
    *)
      rm -f "${file}"
      echo "Error: ${STATUS}, $(basename "${url}" 2>/dev/null) failed to download."
      return 1
      ;;
    esac
  }

  _process_file() {
    local file="${1}" dest="${2}" suffix="${3}" mode="${4}"
    if [ -f "${file}" ]; then
      echo "Info: $(basename "${file}" 2>/dev/null) processing ..."
      [ ! -f "${dest}${suffix}" ] && cp -pf "${dest}" "${dest}${suffix}"
      cp -f "${file}" "${dest}"
      chown root:root "${dest}"
      chmod "${mode}" "${dest}"
    else
      echo "Warning: $(basename "${file}" 2>/dev/null) skipped, not exist."
    fi
  }

  ISDL=false
  [ ! -f "${WORK_PATH}/LICENSE" ] && [ ! -f "${WORK_PATH}/README.md" ] && rm -rf "${WORK_PATH}/patch/${VERSION}/${SS_NAME}"
  if [ ! -d "${WORK_PATH}/patch/${VERSION}/${SS_NAME}" ]; then
    REPO="${REPO:-"ohyeah521/vmm_no_limit"}"
    BRANCH="${BRANCH:-"main"}"

    # 检查版本是否存在
    VERURL="${GPROXY}https://github.com/${REPO}/tree/${BRANCH}/patch/${VERSION}/${SS_NAME}"
    STATUS="$(curl -skL ${CPROXY:+-x ${CPROXY}} -w "%{http_code}" "${VERURL}" -o /dev/null 2>/dev/null)"
    STATUS="${STATUS: -3}"
    case "${STATUS}" in
    "000")
      echo "Error: ${STATUS}, Failed to connect to GitHub. Please check your network and try again."
      exit 1
      ;;
    "200") ;;
    "403")
      echo "Error: ${STATUS}, Access forbidden to the package on GitHub."
      exit 1
      ;;
    "404")
      echo "Error: ${STATUS}, Current version not found patch on GitHub."
      exit 1
      ;;
    *)
      echo "Error: ${STATUS}, Failed to download package from GitHub."
      exit 1
      ;;
    esac

    # 获取 patch 文件
    URL_FIX="${GPROXY}https://github.com/${REPO}/raw/${BRANCH}/patch/${VERSION}/${SS_NAME}"
    for F in "${PATCH_FILES[@]}"; do
      _get_files "${URL_FIX}/${F}" "${WORK_PATH}/patch/${VERSION}/${SS_NAME}/${F}"
      if [ $? -ne 0 ]; then
        rm -rf "${WORK_PATH:?}/patch/${VERSION}/${SS_NAME}"
        exit 1
      fi
    done
    ISDL=true
  fi

  /usr/syno/bin/synopkg stop Virtualization
  sleep 5

  # 处理 patch 文件
  SS_PATH="/var/packages/Virtualization/target"
  _suffix="_backup"
  for F in "${PATCH_FILES[@]}"; do
    _process_file "${WORK_PATH}/patch/${VERSION}/${SS_NAME}/${F}" "${SS_PATH}/${F}" "${_suffix}" 0755
  done

  sleep 5
  /usr/syno/bin/synopkg start Virtualization

  [ "${ISDL}" = true ] && rm -rf "${WORK_PATH:?}/patch/${VERSION}/${SS_NAME}"
}

uninstall() {
  _process_file() {
    local file="${1}" suffix="${2}" mode="${3}"
    if [ -f "${file}${suffix}" ]; then
      echo "Info: $(basename "${file}" 2>/dev/null) restoring ..."
      mv -f "${file}${suffix}" "${file}"
      chown root:root "${file}"
      chmod "${mode}" "${file}"
    else
      echo "Error: $(basename "${file}" 2>/dev/null) skipped, not exist."
    fi
  }

  /usr/syno/bin/synopkg stop Virtualization
  sleep 5

  # 处理 patch 文件
  SS_PATH="/var/packages/Virtualization/target"
  _suffix="_backup"
  for F in "${PATCH_FILES[@]}"; do
    _process_file "${SS_PATH}/${F}" "${_suffix}" 0755
  done

  sleep 5
  /usr/syno/bin/synopkg start Virtualization
}

if [ ! "${USER}" = "root" ]; then
  echo "Error: Please run as root"
  exit 9
fi

if [ ! -x "/usr/syno/bin/synopkg" ]; then
  echo "Error: Please run in Synology system"
  exit 1
fi

VERSION="$(/usr/syno/bin/synopkg version Virtualization 2>/dev/null)"

if [ -z "${VERSION}" ]; then
  # TODO: install ?
  # /usr/syno/bin/synopkg chkupgradepkg 2>/dev/null
  # /usr/syno/bin/synopkg install_from_server Virtualization

  echo "Error: Please install Virtual Machine Manager first"
  exit 1
fi

ARCH="$(synogetkeyvalue /var/packages/Virtualization/INFO arch)"

SS_NAME="Virtualization-${ARCH}-${VERSION}"

PATCH_FILES=(
  "usr/lib/libsynoccc.so"
)

echo "Info: Found ${SS_NAME}"

case "${1}" in
-r | --uninstall)
  uninstall
  ;;
*)
  install
  ;;
esac
