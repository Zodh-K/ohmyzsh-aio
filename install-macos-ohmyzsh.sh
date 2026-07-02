#!/usr/bin/env bash

set -euo pipefail

OH_MY_ZSH_DIR="${HOME}/.oh-my-zsh"
ZSHRC="${HOME}/.zshrc"
FONT_DIR="${HOME}/Library/Fonts"
P10K_DIR="${OH_MY_ZSH_DIR}/custom/themes/powerlevel10k"
NETWORK_MODE="${NETWORK_MODE:-auto}"
GITHUB_PROXY_PREFIX="${GITHUB_PROXY_PREFIX:-https://ghfast.top/}"
NPM_REGISTRY_CN="${NPM_REGISTRY_CN:-https://registry.npmmirror.com}"
HOMEBREW_BREW_GIT_REMOTE_CN="${HOMEBREW_BREW_GIT_REMOTE_CN:-https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git}"
HOMEBREW_CORE_GIT_REMOTE_CN="${HOMEBREW_CORE_GIT_REMOTE_CN:-https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git}"
HOMEBREW_API_DOMAIN_CN="${HOMEBREW_API_DOMAIN_CN:-https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api}"
HOMEBREW_BOTTLE_DOMAIN_CN="${HOMEBREW_BOTTLE_DOMAIN_CN:-https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles}"

info() { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
ok() { printf '\033[1;32m[OK]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m[FAIL]\033[0m %s\n' "$*" >&2; exit 1; }

require_macos() {
  [[ "$(uname -s)" == "Darwin" ]] || fail "This script is for macOS only."
}

ensure_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing command: $1"
}

cn_network_preferred() {
  [[ "${NETWORK_MODE}" == "cn" ]]
}

cn_network_allowed() {
  [[ "${NETWORK_MODE}" != "direct" ]]
}

sanitize_proxy_env() {
  local var value host port
  for var in http_proxy https_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY all_proxy; do
    value="${!var:-}"
    [[ -n "${value}" ]] || continue
    if [[ "${value}" =~ ^[a-zA-Z0-9+.-]+://([^/:]+):([0-9]+) ]]; then
      host="${BASH_REMATCH[1]}"
      port="${BASH_REMATCH[2]}"
      if [[ "${host}" == "127.0.0.1" || "${host}" == "localhost" || "${host}" == "::1" ]]; then
        if ! (echo >/dev/tcp/"${host}"/"${port}") >/dev/null 2>&1; then
          warn "Ignoring unavailable local proxy from ${var}: ${value}"
          unset "${var}"
        fi
      fi
    fi
  done
}

github_proxy_url() {
  local url="$1"
  printf '%s%s' "${GITHUB_PROXY_PREFIX}" "${url}"
}

configure_cn_network() {
  sanitize_proxy_env
  cn_network_allowed || return 0

  export HOMEBREW_BREW_GIT_REMOTE="${HOMEBREW_BREW_GIT_REMOTE_CN}"
  export HOMEBREW_CORE_GIT_REMOTE="${HOMEBREW_CORE_GIT_REMOTE_CN}"
  export HOMEBREW_API_DOMAIN="${HOMEBREW_API_DOMAIN_CN}"
  export HOMEBREW_BOTTLE_DOMAIN="${HOMEBREW_BOTTLE_DOMAIN_CN}"
}

curl_head_ok() {
  curl -fsIL --connect-timeout 8 --max-time 15 "$1" >/dev/null 2>&1
}

verify_cn_mirrors() {
  require_macos
  ensure_curl_available
  sanitize_proxy_env

  local failed=0
  local raw_url
  local font_url
  raw_url="$(github_proxy_url "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh")"
  font_url="$(github_proxy_url "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf")"

  info "Verifying GitHub raw proxy: ${raw_url}"
  curl_head_ok "${raw_url}" && ok "GitHub raw proxy is reachable." || { warn "GitHub raw proxy failed."; failed=1; }

  info "Verifying GitHub font proxy: ${font_url}"
  curl_head_ok "${font_url}" && ok "GitHub file proxy is reachable." || { warn "GitHub file proxy failed."; failed=1; }

  if git_is_usable; then
    info "Verifying GitHub git proxy: $(github_proxy_url "https://github.com/ohmyzsh/ohmyzsh.git")"
    git ls-remote "$(github_proxy_url "https://github.com/ohmyzsh/ohmyzsh.git")" HEAD >/dev/null 2>&1 && ok "GitHub git proxy is reachable." || { warn "GitHub git proxy failed."; failed=1; }
  else
    warn "Git is not available, skipping GitHub git proxy verification."
  fi

  info "Verifying npm mirror: ${NPM_REGISTRY_CN}"
  curl_head_ok "${NPM_REGISTRY_CN}/@electron/asar" && ok "npm mirror is reachable." || { warn "npm mirror failed."; failed=1; }

  info "Verifying Homebrew brew mirror: ${HOMEBREW_BREW_GIT_REMOTE_CN}"
  curl_head_ok "${HOMEBREW_BREW_GIT_REMOTE_CN}/info/refs?service=git-upload-pack" && ok "Homebrew brew mirror is reachable." || { warn "Homebrew brew mirror failed."; failed=1; }

  info "Verifying Homebrew core mirror: ${HOMEBREW_CORE_GIT_REMOTE_CN}"
  curl_head_ok "${HOMEBREW_CORE_GIT_REMOTE_CN}/info/refs?service=git-upload-pack" && ok "Homebrew core mirror is reachable." || { warn "Homebrew core mirror failed."; failed=1; }

  info "Verifying Homebrew API mirror: ${HOMEBREW_API_DOMAIN_CN}"
  curl_head_ok "${HOMEBREW_API_DOMAIN_CN}/formula.jws.json" && ok "Homebrew API mirror is reachable." || { warn "Homebrew API mirror failed."; failed=1; }

  [[ "${failed}" -eq 0 ]] || fail "One or more CN mirrors failed verification. Set NETWORK_MODE=direct to skip CN mirrors."
}

load_homebrew_env() {
  if command -v brew >/dev/null 2>&1; then
    return 0
  elif [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

ensure_curl_available() {
  command -v curl >/dev/null 2>&1 || fail "curl is required to download Homebrew, fonts, and installer resources."
}

git_is_usable() {
  command -v git >/dev/null 2>&1 && git --version >/dev/null 2>&1
}

preflight_checks() {
  require_macos
  ensure_curl_available
  sanitize_proxy_env
  load_homebrew_env

  if command -v brew >/dev/null 2>&1; then
    ok "Homebrew is available: $(brew --version | head -n 1)"
  else
    warn "Homebrew is not installed or not in PATH. The script will install it before running brew commands."
  fi

  if git_is_usable; then
    ok "Git is available: $(git --version)"
  else
    warn "Git is not ready. The script will install Git with Homebrew before cloning repositories."
    warn "If macOS opens a Command Line Tools installer, finish it and rerun this script."
  fi

  command -v zsh >/dev/null 2>&1 && ok "zsh is available: $(zsh --version)" || fail "zsh is required but was not found."
  case "${NETWORK_MODE}" in
    auto) info "Network mode is auto. Official sources are tried first; verified CN mirrors are used as fallback." ;;
    cn) info "Network mode is cn. Verified CN mirrors are preferred." ;;
    direct) info "Network mode is direct. CN mirrors are disabled." ;;
    *) fail "Unknown NETWORK_MODE: ${NETWORK_MODE}. Use auto, cn, or direct." ;;
  esac
}

confirm() {
  local prompt="${1:-Continue?}"
  local answer
  read -r -p "${prompt} [y/N] " answer
  [[ "${answer}" =~ ^[Yy]$ ]]
}

clone_or_update() {
  local repo="$1"
  local dest="$2"
  local proxied_repo
  proxied_repo="$(github_proxy_url "${repo}")"

  if [[ -d "${dest}/.git" ]]; then
    info "Updating ${dest}"
    if cn_network_preferred; then
      git -C "${dest}" -c "url.${GITHUB_PROXY_PREFIX}https://github.com/.insteadOf=https://github.com/" pull --ff-only || git -C "${dest}" pull --ff-only
    elif cn_network_allowed; then
      git -C "${dest}" pull --ff-only || git -C "${dest}" -c "url.${GITHUB_PROXY_PREFIX}https://github.com/.insteadOf=https://github.com/" pull --ff-only
    else
      git -C "${dest}" pull --ff-only
    fi
  elif [[ -e "${dest}" ]]; then
    warn "${dest} already exists and is not a git repository. Skipping."
  else
    if cn_network_preferred; then
      info "Cloning ${repo} via GitHub proxy."
      git clone --depth=1 "${proxied_repo}" "${dest}" || {
        warn "GitHub proxy clone failed. Retrying direct clone: ${repo}"
        git clone --depth=1 "${repo}" "${dest}"
      }
    elif cn_network_allowed; then
      info "Cloning ${repo}"
      git clone --depth=1 "${repo}" "${dest}" || {
        warn "Direct clone failed. Retrying with verified GitHub proxy."
        git clone --depth=1 "${proxied_repo}" "${dest}"
      }
    else
      info "Cloning ${repo}"
      git clone --depth=1 "${repo}" "${dest}"
    fi
  fi
}

install_homebrew() {
  require_macos
  ensure_curl_available
  sanitize_proxy_env
  load_homebrew_env

  if command -v brew >/dev/null 2>&1; then
    ok "Homebrew is already installed: $(brew --version | head -n 1)"
    repair_homebrew_share_permissions
    return
  fi

  info "Installing Homebrew. macOS may ask for your password or Command Line Tools confirmation."
  local install_url="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
  local using_cn_installer=0
  if cn_network_preferred; then
    local proxied_install_url
    proxied_install_url="$(github_proxy_url "${install_url}")"
    if curl_head_ok "${proxied_install_url}"; then
      install_url="${proxied_install_url}"
      using_cn_installer=1
      info "Using verified GitHub proxy for Homebrew installer."
    else
      warn "GitHub proxy for Homebrew installer is unavailable. Falling back to direct URL."
    fi
  elif cn_network_allowed && ! curl_head_ok "${install_url}"; then
    local proxied_install_url
    proxied_install_url="$(github_proxy_url "${install_url}")"
    warn "Official Homebrew installer is not reachable. Trying verified GitHub proxy."
    if curl_head_ok "${proxied_install_url}"; then
      install_url="${proxied_install_url}"
      using_cn_installer=1
    fi
  fi
  [[ "${using_cn_installer}" -eq 1 ]] && configure_cn_network
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL "${install_url}")"

  load_homebrew_env

  command -v brew >/dev/null 2>&1 || fail "Homebrew installed, but brew is not available in PATH. Open a new terminal and retry."
  repair_homebrew_share_permissions
  ok "Homebrew installed."
}

repair_homebrew_share_permissions() {
  load_homebrew_env
  command -v brew >/dev/null 2>&1 || return 0

  local prefix
  prefix="$(brew --prefix)"
  [[ -n "${prefix}" && -d "${prefix}" ]] || return 0

  local share_dir="${prefix}/share"
  local zsh_dir="${share_dir}/zsh"
  local site_functions_dir="${zsh_dir}/site-functions"
  local current_user
  current_user="$(id -un)"

  if [[ ! -d "${share_dir}" ]]; then
    info "Creating Homebrew share directory: ${share_dir}"
    mkdir -p "${share_dir}" 2>/dev/null || sudo mkdir -p "${share_dir}"
  fi

  if [[ ! -w "${share_dir}" ]]; then
    warn "Homebrew share directory is not writable: ${share_dir}"
    warn "This can break brew installs that create shell completions."
    if confirm "Repair Homebrew share permissions now?"; then
      sudo chown -R "${current_user}:admin" "${share_dir}"
      chmod -R u+rwX "${share_dir}"
      ok "Homebrew share permissions repaired."
    else
      warn "Skipped permission repair. Brew may fail with a 'not writable' error."
    fi
  fi

  mkdir -p "${site_functions_dir}" 2>/dev/null || {
    warn "Could not create ${site_functions_dir} without sudo."
    if confirm "Create Homebrew zsh completion directories with sudo?"; then
      sudo mkdir -p "${site_functions_dir}"
      sudo chown -R "${current_user}:admin" "${zsh_dir}"
      chmod -R u+rwX "${zsh_dir}"
    fi
  }

  [[ -w "${share_dir}" ]] && ok "Homebrew share directory is writable."
}

ensure_homebrew_share_writable() {
  load_homebrew_env
  command -v brew >/dev/null 2>&1 || return 0

  local share_dir
  share_dir="$(brew --prefix)/share"
  if [[ ! -w "${share_dir}" ]]; then
    fail "Homebrew share is still not writable: ${share_dir}. Run './install-macos-ohmyzsh.sh brew-permissions' and allow the repair before installing Node.js."
  fi
}

brew_install_if_missing() {
  local formula="$1"
  install_homebrew
  repair_homebrew_share_permissions
  ensure_homebrew_share_writable

  if brew list --versions "${formula}" >/dev/null 2>&1; then
    ok "${formula} is already installed."
  else
    info "Installing ${formula} with Homebrew."
    if cn_network_preferred; then
      configure_cn_network
      brew install "${formula}" || {
        warn "Homebrew CN mirror install failed. Retrying with official Homebrew sources."
        unset HOMEBREW_BREW_GIT_REMOTE HOMEBREW_CORE_GIT_REMOTE HOMEBREW_API_DOMAIN HOMEBREW_BOTTLE_DOMAIN
        brew install "${formula}"
      }
    elif cn_network_allowed; then
      brew install "${formula}" || {
        warn "Official Homebrew install failed. Retrying with verified CN mirrors."
        configure_cn_network
        brew install "${formula}"
      }
    else
      brew install "${formula}"
    fi
  fi
}

ensure_git_available() {
  if git_is_usable; then
    ok "Git is available: $(git --version)"
    return
  fi

  warn "Git is not usable yet. Installing Git with Homebrew."
  brew_install_if_missing git
  hash -r 2>/dev/null || true
  git_is_usable || fail "Git is still unavailable. If macOS is installing Command Line Tools, finish that installer and rerun this script."
}

install_node_and_asar() {
  brew_install_if_missing node
  brew_install_if_missing autojump
  info "Installing @electron/asar globally."
  if cn_network_preferred; then
    npm install -g @electron/asar --registry="${NPM_REGISTRY_CN}" || {
      warn "npm mirror install failed. Retrying with default npm registry."
      npm install -g @electron/asar
    }
  elif cn_network_allowed; then
    npm install -g @electron/asar || {
      warn "Default npm registry failed. Retrying with verified npm mirror."
      npm install -g @electron/asar --registry="${NPM_REGISTRY_CN}"
    }
  else
    npm install -g @electron/asar
  fi
  ok "Node.js, npm, @electron/asar, and autojump are ready."
}

install_oh_my_zsh() {
  require_macos
  ensure_git_available

  clone_or_update "https://github.com/ohmyzsh/ohmyzsh.git" "${OH_MY_ZSH_DIR}"
  clone_or_update "https://github.com/romkatv/powerlevel10k.git" "${P10K_DIR}"
  clone_or_update "https://github.com/zsh-users/zsh-autosuggestions.git" "${OH_MY_ZSH_DIR}/custom/plugins/zsh-autosuggestions"
  clone_or_update "https://github.com/zsh-users/zsh-syntax-highlighting.git" "${OH_MY_ZSH_DIR}/custom/plugins/zsh-syntax-highlighting"
  clone_or_update "https://github.com/zsh-users/zsh-completions.git" "${OH_MY_ZSH_DIR}/custom/plugins/zsh-completions"

  ok "Oh My Zsh, Powerlevel10k, and plugins are installed."
}

install_fonts() {
  require_macos
  ensure_curl_available
  sanitize_proxy_env
  mkdir -p "${FONT_DIR}"

  local base="https://github.com/romkatv/powerlevel10k-media/raw/master"
  local fonts=(
    "MesloLGS NF Regular.ttf"
    "MesloLGS NF Bold.ttf"
    "MesloLGS NF Italic.ttf"
    "MesloLGS NF Bold Italic.ttf"
  )

  for font in "${fonts[@]}"; do
    local target="${FONT_DIR}/${font}"
    local encoded="${font// /%20}"
    if [[ -f "${target}" ]]; then
      ok "Font already installed: ${font}"
    else
      info "Downloading font: ${font}"
      local font_url="${base}/${encoded}"
      local download_url="${font_url}"
      if cn_network_preferred; then
        download_url="$(github_proxy_url "${font_url}")"
        curl -fL "${download_url}" -o "${target}" || {
          warn "Font download through CN proxy failed. Retrying direct URL."
          curl -fL "${font_url}" -o "${target}"
        }
      elif cn_network_allowed; then
        curl -fL "${font_url}" -o "${target}" || {
          warn "Direct font download failed. Retrying with verified GitHub proxy."
          curl -fL "$(github_proxy_url "${font_url}")" -o "${target}"
        }
      else
        curl -fL "${font_url}" -o "${target}"
      fi
    fi
  done

  ok "MesloLGS Nerd Font files are installed in ${FONT_DIR}."
  warn "If your terminal does not change automatically, set the terminal font to 'MesloLGS NF'."
}

configure_zshrc() {
  require_macos
  [[ -d "${OH_MY_ZSH_DIR}" ]] || install_oh_my_zsh

  local backup="${ZSHRC}.backup.$(date +%Y%m%d%H%M%S)"
  if [[ -f "${ZSHRC}" ]]; then
    cp "${ZSHRC}" "${backup}"
    info "Backed up existing .zshrc to ${backup}"
  fi

  cp "${OH_MY_ZSH_DIR}/templates/zshrc.zsh-template" "${ZSHRC}"

  /usr/bin/perl -0pi -e 's/ZSH_THEME="[^"]*"/ZSH_THEME="powerlevel10k\/powerlevel10k"/' "${ZSHRC}"
  /usr/bin/perl -0pi -e 's/(ZSH_THEME="powerlevel10k\/powerlevel10k"\n)/$1\n# 指定终端标题\nDISABLE_AUTO_TITLE="true"\n/' "${ZSHRC}"
  /usr/bin/perl -0pi -e 's/plugins=\([^)]+\)/plugins=(\n  git\n  autojump\n  zsh-autosuggestions\n  zsh-syntax-highlighting\n  zsh-completions\n)/s' "${ZSHRC}"

  local tmp_zshrc
  tmp_zshrc="$(mktemp)"
  cat >"${tmp_zshrc}" <<'ZSHRC_TOP'
# Powerlevel10k instant prompt. Keep this at the top of ~/.zshrc when customizing later.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

ZSHRC_TOP
  cat "${ZSHRC}" >>"${tmp_zshrc}"
  cat >>"${tmp_zshrc}" <<'ZSHRC_BOTTOM'

# Homebrew environment for Apple Silicon and Intel Macs.
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# 加载补全
if type brew &>/dev/null; then
    FPATH=$(brew --prefix)/share/zsh-completions:$FPATH

    autoload -Uz compinit
    compinit
fi

# 快捷命令
alias seconfig="open ~/.zshrc"
alias reconfig="source ~/.zshrc"
alias xf="sudo xattr -r -d com.apple.quarantine"
alias yc="chflags hidden"
alias qxyc="chflags nohidden"
alias qm="sudo codesign --force --deep --sign -"

# autojump配置
[ -f /usr/local/etc/profile.d/autojump.sh ] && . /usr/local/etc/profile.d/autojump.sh
[ -f /opt/homebrew/etc/profile.d/autojump.sh ] && . /opt/homebrew/etc/profile.d/autojump.sh
ZSHRC_BOTTOM
  mv "${tmp_zshrc}" "${ZSHRC}"

  verify_zshrc_personalization
  ok ".zshrc has been configured for Powerlevel10k and plugins."
}

verify_zshrc_personalization() {
  local missing=0
  local checks=(
    'DISABLE_AUTO_TITLE="true"'
    'FPATH=$(brew --prefix)/share/zsh-completions:$FPATH'
    'plugins=('
    'autojump'
    'alias seconfig="open ~/.zshrc"'
    'alias reconfig="source ~/.zshrc"'
    'alias xf="sudo xattr -r -d com.apple.quarantine"'
    'alias yc="chflags hidden"'
    'alias qxyc="chflags nohidden"'
    'alias qm="sudo codesign --force --deep --sign -"'
    '/usr/local/etc/profile.d/autojump.sh'
  )

  for pattern in "${checks[@]}"; do
    if grep -Fq "${pattern}" "${ZSHRC}"; then
      ok ".zshrc contains: ${pattern}"
    else
      warn ".zshrc is missing: ${pattern}"
      missing=1
    fi
  done

  [[ "${missing}" -eq 0 ]] || fail ".zshrc personalization check failed."
}

set_default_shell() {
  local zsh_path
  zsh_path="$(command -v zsh || true)"
  [[ -n "${zsh_path}" ]] || fail "zsh is not installed."

  if [[ "${SHELL}" == "${zsh_path}" ]]; then
    ok "Default shell is already zsh."
    return
  fi

  warn "Changing the default shell may ask for your macOS password."
  if confirm "Set zsh as your default shell now?"; then
    chsh -s "${zsh_path}"
    ok "Default shell changed to ${zsh_path}. Open a new terminal after this script finishes."
  else
    warn "Skipped changing default shell. You can run: chsh -s ${zsh_path}"
  fi
}

run_p10k_configure() {
  configure_zshrc
  info "Starting Powerlevel10k configuration wizard."
  info "Choose the style you like in the prompts that follow."
  zsh -ic 'p10k configure'
}

full_install() {
  preflight_checks
  install_node_and_asar
  install_oh_my_zsh
  install_fonts
  configure_zshrc
  set_default_shell

  if confirm "Launch Powerlevel10k configuration wizard now?"; then
    run_p10k_configure
  else
    warn "Skipped wizard. Run 'p10k configure' later in a new terminal."
  fi

  ok "All done. Open a new terminal window to use the new shell."
}

show_status() {
  sanitize_proxy_env
  load_homebrew_env
  printf '\nCurrent status:\n'
  echo "Network mode: ${NETWORK_MODE}"
  cn_network_allowed && echo "GitHub proxy prefix: ${GITHUB_PROXY_PREFIX}"
  command -v brew >/dev/null 2>&1 && brew --version | head -n 1 || echo "Homebrew: not installed"
  command -v node >/dev/null 2>&1 && node --version || echo "Node.js: not installed"
  command -v npm >/dev/null 2>&1 && npm --version || echo "npm: not installed"
  command -v asar >/dev/null 2>&1 && asar --version || echo "@electron/asar: not installed"
  command -v autojump >/dev/null 2>&1 && echo "autojump: installed" || echo "autojump: not installed"
  if command -v brew >/dev/null 2>&1; then
    local brew_share
    brew_share="$(brew --prefix)/share"
    [[ -w "${brew_share}" ]] && echo "Homebrew share: writable" || echo "Homebrew share: not writable (${brew_share})"
  fi
  [[ -d "${OH_MY_ZSH_DIR}" ]] && echo "Oh My Zsh: installed" || echo "Oh My Zsh: not installed"
  [[ -d "${P10K_DIR}" ]] && echo "Powerlevel10k: installed" || echo "Powerlevel10k: not installed"
  [[ -f "${FONT_DIR}/MesloLGS NF Regular.ttf" ]] && echo "MesloLGS NF: installed" || echo "MesloLGS NF: not installed"
  [[ -f "${ZSHRC}" ]] && echo ".zshrc: exists" || echo ".zshrc: missing"
  printf '\n'
}

show_menu() {
  cat <<'MENU'

macOS Oh My Zsh bootstrap

1) Full install: brew + node/npm + asar + autojump + Oh My Zsh + p10k + fonts + .zshrc
2) Install Homebrew + Node.js/npm + @electron/asar + autojump
3) Install/Update Oh My Zsh + Powerlevel10k + plugins
4) Install MesloLGS Nerd Fonts
5) Configure ~/.zshrc
6) Run Powerlevel10k configuration wizard
7) Show install status
8) Repair Homebrew share permissions
9) Run preflight checks
10) Verify CN mirrors/proxies
0) Exit

MENU
}

main_menu() {
  local choice
  while true; do
    show_menu
    read -r -p "Choose an option: " choice
    case "${choice}" in
      1) full_install ;;
      2) install_node_and_asar ;;
      3) install_oh_my_zsh ;;
      4) install_fonts ;;
      5) configure_zshrc ;;
      6) run_p10k_configure ;;
      7) show_status ;;
      8) repair_homebrew_share_permissions ;;
      9) preflight_checks ;;
      10) verify_cn_mirrors ;;
      0) exit 0 ;;
      *) warn "Unknown option: ${choice}" ;;
    esac
  done
}

case "${1:-menu}" in
  full) full_install ;;
  brew-node-asar) install_node_and_asar ;;
  ohmyzsh) install_oh_my_zsh ;;
  fonts) install_fonts ;;
  zshrc) configure_zshrc ;;
  p10k) run_p10k_configure ;;
  brew-permissions) repair_homebrew_share_permissions ;;
  preflight) preflight_checks ;;
  verify-cn-mirrors) verify_cn_mirrors ;;
  status) show_status ;;
  menu) main_menu ;;
  -h|--help|help)
    echo "Usage: $0 [menu|full|brew-node-asar|ohmyzsh|fonts|zshrc|p10k|brew-permissions|preflight|verify-cn-mirrors|status]"
    ;;
  *)
    fail "Unknown command: $1. Run '$0 --help'."
    ;;
esac
