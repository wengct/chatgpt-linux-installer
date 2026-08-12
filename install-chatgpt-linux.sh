#!/usr/bin/env bash

set -Eeuo pipefail

PROGRAM_NAME="${0##*/}"

DEB_AMD64_URL='https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_amd64.deb'
DEB_ARM64_URL='https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_arm64.deb'
RPM_X86_64_URL='https://persistent.oaistatic.com/codex-app-prod/linux/rpm/latest/chatgpt.x86_64.rpm'
RPM_AARCH64_URL='https://persistent.oaistatic.com/codex-app-prod/linux/rpm/latest/chatgpt.aarch64.rpm'

PACKAGE_URL="${CHATGPT_PACKAGE_URL:-}"
PACKAGE_FILE=''
EXPECTED_SHA256="${CHATGPT_PACKAGE_SHA256:-}"
DOWNLOAD_DIR="${CHATGPT_DOWNLOAD_DIR:-${HOME}/Downloads}"
KEEP_PACKAGE=1
LAUNCH_AFTER_INSTALL=0
SETUP_IME=0
PRINT_URL=0
TEMP_DIR=''

usage() {
  cat <<EOF
自動下載並安裝最新版 ChatGPT for Linux。

支援：
  Debian/Ubuntu：x64、arm64 .deb
  Fedora/RHEL：  x64、arm64 .rpm

用法：
  $PROGRAM_NAME [選項]

選項：
  --url URL          改用指定的 HTTPS 套件網址
  --file PATH        安裝本機既有的 .deb 或 .rpm
  --sha256 HASH      驗證套件 SHA-256
  --download-dir DIR 保留下載檔的位置（預設：$DOWNLOAD_DIR）
  --no-keep          安裝後不保留本次下載的套件
  --ime              安裝／設定 IBus 新酷音與 ChatGPT 相容啟動器
  --launch           安裝完成後啟動 ChatGPT
  --print-url        只顯示目前系統對應的官方下載網址
  -h, --help         顯示說明

環境變數：
  CHATGPT_PACKAGE_URL
  CHATGPT_PACKAGE_SHA256
  CHATGPT_DOWNLOAD_DIR

請用一般使用者執行；腳本會在需要時自行呼叫 sudo。
EOF
}

info() { printf '==> %s\n' "$*"; }
warn() { printf '警告：%s\n' "$*" >&2; }
die()  { printf '錯誤：%s\n' "$*" >&2; exit 1; }

cleanup() {
  if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
    rm -rf -- "$TEMP_DIR"
  fi
}
trap cleanup EXIT INT TERM

while (($#)); do
  case "$1" in
    --url)
      (($# >= 2)) || die '--url 缺少網址'
      PACKAGE_URL="$2"
      shift 2
      ;;
    --file)
      (($# >= 2)) || die '--file 缺少路徑'
      PACKAGE_FILE="$2"
      shift 2
      ;;
    --sha256)
      (($# >= 2)) || die '--sha256 缺少雜湊值'
      EXPECTED_SHA256="${2,,}"
      shift 2
      ;;
    --download-dir)
      (($# >= 2)) || die '--download-dir 缺少路徑'
      DOWNLOAD_DIR="$2"
      shift 2
      ;;
    --no-keep) KEEP_PACKAGE=0; shift ;;
    --ime) SETUP_IME=1; shift ;;
    --launch) LAUNCH_AFTER_INSTALL=1; shift ;;
    --print-url) PRINT_URL=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "不支援的參數：$1" ;;
  esac
done

[[ -z "$PACKAGE_URL" || -z "$PACKAGE_FILE" ]] || die '--url 與 --file 只能擇一'
[[ "$(uname -s)" == Linux ]] || die '此腳本只能在 Linux 執行'
[[ -r /etc/os-release ]] || die '找不到 /etc/os-release，無法辨識發行版'

# shellcheck disable=SC1091
source /etc/os-release

case "${ID:-}:${ID_LIKE:-}" in
  *debian*|*ubuntu*) PACKAGE_FORMAT='deb'; PACKAGE_MANAGER='apt' ;;
  *fedora*|*rhel*)   PACKAGE_FORMAT='rpm'; PACKAGE_MANAGER='dnf' ;;
  *) die "不支援的發行版：${PRETTY_NAME:-未知}" ;;
esac

case "$(uname -m)" in
  x86_64|amd64)
    CPU_FAMILY='x64'
    DEB_ARCH='amd64'
    RPM_ARCH='x86_64'
    ;;
  aarch64|arm64)
    CPU_FAMILY='arm64'
    DEB_ARCH='arm64'
    RPM_ARCH='aarch64'
    ;;
  *) die "不支援的 CPU 架構：$(uname -m)" ;;
esac

if [[ "$PACKAGE_FORMAT:$CPU_FAMILY" == 'deb:x64' ]]; then
  OFFICIAL_URL="$DEB_AMD64_URL"
  OFFICIAL_FILENAME='chatgpt_amd64.deb'
elif [[ "$PACKAGE_FORMAT:$CPU_FAMILY" == 'deb:arm64' ]]; then
  OFFICIAL_URL="$DEB_ARM64_URL"
  OFFICIAL_FILENAME='chatgpt_arm64.deb'
elif [[ "$PACKAGE_FORMAT:$CPU_FAMILY" == 'rpm:x64' ]]; then
  OFFICIAL_URL="$RPM_X86_64_URL"
  OFFICIAL_FILENAME='chatgpt.x86_64.rpm'
else
  OFFICIAL_URL="$RPM_AARCH64_URL"
  OFFICIAL_FILENAME='chatgpt.aarch64.rpm'
fi

if ((PRINT_URL)); then
  printf '%s\n' "$OFFICIAL_URL"
  exit 0
fi

((EUID != 0)) || die '請不要用 sudo 執行整支腳本；請以一般使用者執行'
command -v sudo >/dev/null 2>&1 || die '找不到 sudo'

if [[ -n "$PACKAGE_FILE" ]]; then
  [[ -r "$PACKAGE_FILE" ]] || die "無法讀取套件：$PACKAGE_FILE"
  case "$PACKAGE_FILE" in
    *.deb) [[ "$PACKAGE_FORMAT" == deb ]] || die '目前系統不能安裝 .deb' ;;
    *.rpm) [[ "$PACKAGE_FORMAT" == rpm ]] || die '目前系統不能安裝 .rpm' ;;
    *) die '--file 必須是 .deb 或 .rpm' ;;
  esac
else
  PACKAGE_URL="${PACKAGE_URL:-$OFFICIAL_URL}"
  [[ "$PACKAGE_URL" == https://* ]] || die '--url 僅接受 HTTPS'

  if [[ "$PACKAGE_MANAGER" == apt ]]; then
    sudo apt-get update
    sudo apt-get install -y --no-install-recommends ca-certificates curl
  else
    sudo dnf install -y ca-certificates curl
  fi

  TEMP_DIR="$(mktemp -d)"
  PACKAGE_FILE="$TEMP_DIR/$OFFICIAL_FILENAME"
  info "下載 $PACKAGE_URL"
  curl --fail --location --show-error --retry 4 --retry-all-errors \
    --connect-timeout 20 --output "$PACKAGE_FILE" "$PACKAGE_URL"
  [[ -s "$PACKAGE_FILE" ]] || die '下載結果是空檔案'
fi

if [[ -n "$EXPECTED_SHA256" ]]; then
  [[ "$EXPECTED_SHA256" =~ ^[0-9a-f]{64}$ ]] || die '--sha256 必須是 64 位十六進位字串'
  ACTUAL_SHA256="$(sha256sum "$PACKAGE_FILE" | awk '{print $1}')"
  [[ "$ACTUAL_SHA256" == "$EXPECTED_SHA256" ]] || die "SHA-256 不符：$ACTUAL_SHA256"
  info 'SHA-256 驗證通過'
else
  warn "官方目前未在下載頁提供固定 SHA-256；本次檔案雜湊：$(sha256sum "$PACKAGE_FILE" | awk '{print $1}')"
fi

if [[ "$PACKAGE_FORMAT" == deb ]]; then
  dpkg-deb --info "$PACKAGE_FILE" >/dev/null 2>&1 || die '不是有效的 Debian 套件'
  PACKAGE_NAME="$(dpkg-deb -f "$PACKAGE_FILE" Package)"
  PACKAGE_VERSION="$(dpkg-deb -f "$PACKAGE_FILE" Version)"
  PACKAGE_ARCH="$(dpkg-deb -f "$PACKAGE_FILE" Architecture)"
  PACKAGE_MAINTAINER="$(dpkg-deb -f "$PACKAGE_FILE" Maintainer)"
  [[ "$PACKAGE_NAME" == chatgpt ]] || die "套件名稱不是 chatgpt：$PACKAGE_NAME"
  [[ "$PACKAGE_ARCH" == "$DEB_ARCH" || "$PACKAGE_ARCH" == all ]] || die "架構不符：$PACKAGE_ARCH"
  [[ "$PACKAGE_MAINTAINER" == *OpenAI* ]] || die "套件維護者不是 OpenAI：$PACKAGE_MAINTAINER"
  info "安裝 ChatGPT $PACKAGE_VERSION ($PACKAGE_ARCH)"
  sudo apt-get install -y -- "$PACKAGE_FILE"
else
  command -v rpm >/dev/null 2>&1 || sudo dnf install -y rpm
  rpm -K "$PACKAGE_FILE" >/dev/null 2>&1 || warn 'RPM 未提供可由本機信任鏈驗證的簽章'
  PACKAGE_NAME="$(rpm -qp --qf '%{NAME}' "$PACKAGE_FILE")"
  PACKAGE_VERSION="$(rpm -qp --qf '%{VERSION}-%{RELEASE}' "$PACKAGE_FILE")"
  PACKAGE_ARCH="$(rpm -qp --qf '%{ARCH}' "$PACKAGE_FILE")"
  PACKAGE_VENDOR="$(rpm -qp --qf '%{VENDOR}' "$PACKAGE_FILE")"
  [[ "$PACKAGE_NAME" == chatgpt ]] || die "套件名稱不是 chatgpt：$PACKAGE_NAME"
  [[ "$PACKAGE_ARCH" == "$RPM_ARCH" || "$PACKAGE_ARCH" == noarch ]] || die "架構不符：$PACKAGE_ARCH"
  [[ "$PACKAGE_VENDOR" == *OpenAI* ]] || warn "RPM Vendor 欄位不是 OpenAI：$PACKAGE_VENDOR"
  info "安裝 ChatGPT $PACKAGE_VERSION ($PACKAGE_ARCH)"
  sudo dnf install -y "$PACKAGE_FILE"
fi

[[ -x /usr/bin/chatgpt ]] || die '安裝完成，但找不到 /usr/bin/chatgpt'

if [[ -n "$TEMP_DIR" && "$KEEP_PACKAGE" == 1 ]]; then
  mkdir -p -- "$DOWNLOAD_DIR"
  SAVED_PACKAGE="$DOWNLOAD_DIR/$OFFICIAL_FILENAME"
  if [[ -e "$SAVED_PACKAGE" ]]; then
    SAVED_PACKAGE="$DOWNLOAD_DIR/chatgpt_${PACKAGE_VERSION}_${PACKAGE_ARCH}.${PACKAGE_FORMAT}"
  fi
  install -m 0644 "$PACKAGE_FILE" "$SAVED_PACKAGE"
  info "已保留安裝檔：$SAVED_PACKAGE"
fi

if ((SETUP_IME)); then
  if [[ -z "$TEMP_DIR" ]]; then
    TEMP_DIR="$(mktemp -d)"
  fi

  info '安裝並設定 IBus 新酷音'
  if [[ "$PACKAGE_MANAGER" == apt ]]; then
    sudo apt-get install -y ibus ibus-chewing im-config fonts-noto-cjk
    im-config -n ibus
  else
    sudo dnf install -y ibus ibus-chewing google-noto-cjk-fonts
  fi

  gsettings set org.freedesktop.ibus.general preload-engines "['xkb:us::eng', 'chewing']"
  gsettings set org.freedesktop.ibus.general engines-order "['chewing', 'xkb:us::eng']"
  gsettings set org.freedesktop.ibus.general.hotkey triggers "['<Control>space']"
  gsettings set org.freedesktop.IBus.Chewing chi-eng-mode-toggle 'shift'
  gsettings set org.freedesktop.IBus.Chewing easy-symbol-input true
  gsettings set org.freedesktop.IBus.Chewing default-english-case 'lowercase'
  gsettings set org.freedesktop.ibus.panel show 1

  info '建立 ChatGPT 的 IBus/WSLg 相容啟動器'
  WRAPPER_TEMP="$TEMP_DIR/chatgpt-wrapper"
  cat >"$WRAPPER_TEMP" <<'WRAPPER'
#!/bin/sh
runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export XDG_RUNTIME_DIR="$runtime_dir"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=$runtime_dir/bus}"
export GTK_IM_MODULE=ibus
export QT_IM_MODULE=ibus
export XMODIFIERS=@im=ibus
if ! ibus engine >/dev/null 2>&1; then
    ibus-daemon --daemonize --xim --restart --panel=/usr/libexec/ibus-ui-gtk3
    sleep 1
fi
if ! pgrep -x ibus-ui-gtk3 >/dev/null 2>&1; then
    /usr/libexec/ibus-ui-gtk3 >/tmp/ibus-ui-gtk3.log 2>&1 &
    sleep 1
fi
ibus engine chewing >/dev/null 2>&1 || true
exec /usr/bin/chatgpt --ozone-platform=x11 "$@"
WRAPPER
  sudo install -m 0755 "$WRAPPER_TEMP" /usr/local/bin/chatgpt

  ibus-daemon --daemonize --replace --xim --restart --panel=/usr/libexec/ibus-ui-gtk3
  sleep 2
  ibus engine chewing || true
fi

INSTALLED_VERSION='未知'
if [[ "$PACKAGE_MANAGER" == apt ]]; then
  INSTALLED_VERSION="$(dpkg-query -W -f='${Version}' chatgpt)"
else
  INSTALLED_VERSION="$(rpm -q --qf '%{VERSION}-%{RELEASE}' chatgpt)"
fi

printf '\nChatGPT %s 安裝完成。\n' "$INSTALLED_VERSION"
printf '啟動指令：chatgpt\n'
if ((SETUP_IME)); then
  printf '中文輸入：Ctrl+Space 啟用酷音；單按 Shift 切換中英文。\n'
fi

if [[ ! -d /mnt/wslg && -z "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]]; then
  warn '未偵測到圖形顯示環境；套件已安裝，但目前不能顯示視窗'
fi

if ((LAUNCH_AFTER_INSTALL)); then
  info '啟動 ChatGPT'
  nohup chatgpt >"${TMPDIR:-/tmp}/chatgpt-linux.log" 2>&1 &
fi
