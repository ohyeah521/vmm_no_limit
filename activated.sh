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
    echo "Downloading $(basename "${url}" 2>/dev/null) ..."
    mkdir -p "$(dirname "${file}" 2>/dev/null)" 2>/dev/null
    STATUS="$(curl -skL -w "%{http_code}" "${url}" -o "${file}")"
    STATUS="${STATUS: -3}"
    case "${STATUS}" in
    "200") ;;
    "403")
      rm -rf "${file}"
      echo "Error: ${STATUS}, Access forbidden to the package on GitHub."
      exit 1
      ;;
    "404")
      rm -rf "${file}"
      echo "Warning: ${file} not exist, skip."
      ;;
    *)
      rm -rf "${file}"
      echo "Error: ${STATUS}, Failed to download ${url} from GitHub."
      exit 1
      ;;
    esac
  }
  
  _process_file() {
    local file="${1}" dest="${2}" suffix="${3}" mode="${4}"
    echo "Patch ${dest}"
    [ ! -f "${file}" ] && {
      echo "Warning: ${file} not exist, skip."
      return 1
    }
    [ ! -f "${dest}${suffix}" ] && cp -pf "${dest}" "${dest}${suffix}"
    cp -f "${file}" "${dest}"
    chown root:root "${dest}"
    chmod "${mode}" "${dest}"
  }

  ISDL=false
  if [ ! -d "${WORK_PATH}/patch/${VERSION}/${SS_NAME}" ]; then
    REPO="${REPO:-"ohyeah521/vmm_no_limit"}"
    BRANCH="${BRANCH:-"main"}"

    # 检查版本是否存在
    VERURL="https://github.com/${REPO}/tree/${BRANCH}/patch/${VERSION}/${SS_NAME}"
    STATUS="$(curl -s -m 10 -connect-timeout 10 -w "%{http_code}" "${VERURL}" -o /dev/null 2>/dev/null)"
    STATUS="${STATUS: -3}"
    case "${STATUS}" in
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
    URL_FIX="https://github.com/${REPO}/raw/${BRANCH}/patch/${VERSION}/${SS_NAME}"
    for F in "${PATCH_FILES[@]}"; do
      _get_files "${URL_FIX}/${F}" "${WORK_PATH}/patch/${VERSION}/${SS_NAME}/${F}"
    done
    ISDL=true
  fi

  /usr/syno/bin/synopkg stop Virtualization >/dev/null 2>&1
  sleep 5

  # # 屏蔽认证服务器
  # if grep -q "synovirtualization.synology.com" /etc/hosts; then
  #   echo "Already blocked license server: synovirtualization.synology.com."
  # else
  #   echo "Add block license server: synovirtualization.synology.com"
  #   echo "0.0.0.0 synovirtualization.synology.com" | sudo tee -a /etc/hosts
  # fi

  # 处理 patch 文件
  SS_PATH="/var/packages/Virtualization/target"
  _suffix="_backup"
  for F in "${PATCH_FILES[@]}"; do
    _process_file "${WORK_PATH}/patch/${VERSION}/${SS_NAME}/${F}" "${SS_PATH}/${F}" "${_suffix}" 0755
  done

  sleep 5
  /usr/syno/bin/synopkg start Virtualization >/dev/null 2>&1

  [ "${ISDL}" = true ] && rm -rf "${WORK_PATH:?}/patch/${VERSION}/${SS_NAME}"
}

uninstall() {
  _process_file() {
    local file="${1}" suffix="${2}" mode="${3}"
    if [ -f "${file}${suffix}" ]; then
      echo "Restore ${file}"
      mv -f "${file}${suffix}" "${file}"
      chown root:root "${file}"
      chmod "${mode}" "${file}"
    else
      echo "Error: Backup file for ${file} does not exist"
    fi
  }

  /usr/syno/bin/synopkg stop Virtualization >/dev/null 2>&1
  sleep 5

  # 处理 patch 文件
  SS_PATH="/var/packages/Virtualization/target"
  _suffix="_backup"
  for F in "${PATCH_FILES[@]}"; do
    _process_file "${SS_PATH}/${F}" "${_suffix}" 0755
  done

  # # 解除屏蔽认证服务器
  # if grep -q "synovirtualization.synology.com" /etc/hosts; then
  #   echo "Unblocking license server: synovirtualization.synology.com"
  #   sudo sed -i '/synovirtualization.synology.com/d' /etc/hosts
  # else
  #   echo "License server not blocked: synovirtualization.synology.com."
  # fi

  sleep 5
  /usr/syno/bin/synopkg start Virtualization >/dev/null 2>&1
}

if [ ! "${USER}" = "root" ]; then
  echo "Please run as root"
  exit 9
fi

if [ ! -x "/usr/syno/bin/synopkg" ]; then
  echo "Please run in Synology system"
  exit 1
fi

VERSION="$(/usr/syno/bin/synopkg version Virtualization 2>/dev/null)"

if [ -z "${VERSION}" ]; then
  # TODO: install ?
  # /usr/syno/bin/synopkg chkupgradepkg 2>/dev/null
  # /usr/syno/bin/synopkg install_from_server Virtualization

  echo "Please install Virtual Machine Manager first"
  exit 1
fi

ARCH="$(synogetkeyvalue /var/packages/Virtualization/INFO arch)"

SS_NAME="Virtualization-${ARCH}-${VERSION}"

PATCH_FILES=(
  "usr/lib/libsynoccc.so"
)

echo "Found ${SS_NAME}"

case "${1}" in
-r | --uninstall)
  uninstall
  ;;
*)
  install
  ;;
esac
