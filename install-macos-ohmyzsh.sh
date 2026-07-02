#!/usr/bin/env bash

set -euo pipefail

OH_MY_ZSH_DIR="${HOME}/.oh-my-zsh"
ZSHRC="${HOME}/.zshrc"
FONT_DIR="${HOME}/Library/Fonts"
P10K_DIR="${OH_MY_ZSH_DIR}/custom/themes/powerlevel10k"

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

confirm() {
  local prompt="${1:-Continue?}"
  local answer
  read -r -p "${prompt} [y/N] " answer
  [[ "${answer}" =~ ^[Yy]$ ]]
}

clone_or_update() {
  local repo="$1"
  local dest="$2"

  if [[ -d "${dest}/.git" ]]; then
    info "Updating ${dest}"
    git -C "${dest}" pull --ff-only
  elif [[ -e "${dest}" ]]; then
    warn "${dest} already exists and is not a git repository. Skipping."
  else
    info "Cloning ${repo}"
    git clone --depth=1 "${repo}" "${dest}"
  fi
}

install_homebrew() {
  require_macos
  if command -v brew >/dev/null 2>&1; then
    ok "Homebrew is already installed: $(brew --version | head -n 1)"
    repair_homebrew_share_permissions
    return
  fi

  info "Installing Homebrew. macOS may ask for your password or Command Line Tools confirmation."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi

  command -v brew >/dev/null 2>&1 || fail "Homebrew installed, but brew is not available in PATH. Open a new terminal and retry."
  repair_homebrew_share_permissions
  ok "Homebrew installed."
}

repair_homebrew_share_permissions() {
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
  command -v brew >/dev/null 2>&1 || return 0

  local share_dir
  share_dir="$(brew --prefix)/share"
  if [[ ! -w "${share_dir}" ]]; then
    fail "Homebrew share is still not writable: ${share_dir}. Run './install-macos-ohmyzsh.sh brew-permissions' and allow the repair before installing Node.js."
  fi
}

install_node_and_asar() {
  install_homebrew
  repair_homebrew_share_permissions
  ensure_homebrew_share_writable
  info "Installing Node.js with Homebrew."
  brew install node
  info "Installing autojump with Homebrew."
  brew install autojump
  info "Installing @electron/asar globally."
  npm install -g @electron/asar
  ok "Node.js, npm, @electron/asar, and autojump are ready."
}

install_oh_my_zsh() {
  require_macos
  ensure_command git

  clone_or_update "https://github.com/ohmyzsh/ohmyzsh.git" "${OH_MY_ZSH_DIR}"
  clone_or_update "https://github.com/romkatv/powerlevel10k.git" "${P10K_DIR}"
  clone_or_update "https://github.com/zsh-users/zsh-autosuggestions.git" "${OH_MY_ZSH_DIR}/custom/plugins/zsh-autosuggestions"
  clone_or_update "https://github.com/zsh-users/zsh-syntax-highlighting.git" "${OH_MY_ZSH_DIR}/custom/plugins/zsh-syntax-highlighting"
  clone_or_update "https://github.com/zsh-users/zsh-completions.git" "${OH_MY_ZSH_DIR}/custom/plugins/zsh-completions"

  ok "Oh My Zsh, Powerlevel10k, and plugins are installed."
}

install_fonts() {
  require_macos
  ensure_command curl
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
      curl -fL "${base}/${encoded}" -o "${target}"
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
  printf '\nCurrent status:\n'
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
  status) show_status ;;
  menu) main_menu ;;
  -h|--help|help)
    echo "Usage: $0 [menu|full|brew-node-asar|ohmyzsh|fonts|zshrc|p10k|brew-permissions|status]"
    ;;
  *)
    fail "Unknown command: $1. Run '$0 --help'."
    ;;
esac
