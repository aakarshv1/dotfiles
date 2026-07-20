#!/usr/bin/env bash
# =============================================================================
# dotfiles/setup.sh
#
# One-shot setup for a terminal-first dev environment.
# Works on local machines (macOS/Linux) and HPC clusters (no root needed).
#
# Installs:
#   - neovim 0.10+
#   - tmux 3.4+
#   - ripgrep
#   - fd
#   - nvm + node (LTS)
#   - tpm (tmux plugin manager)
#   - neovim config (init.lua)
#   - tmux config (.tmux.conf)
#
# Usage:
#   git clone https://github.com/YOUR_USERNAME/dotfiles.git
#   cd dotfiles
#   bash setup.sh
#
# Re-running is safe. It skips anything already installed at the right version.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"

NVIM_VERSION="v0.12.3"   # config uses the native LSP API (vim.lsp.config), needs >= 0.11
RIPGREP_VERSION="14.1.1"
FD_VERSION="10.2.0"
TMUX_VERSION="3.4"
NVM_VERSION="v0.40.1"

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

info()  { printf "\033[1;34m[INFO]\033[0m  %s\n" "$1"; }
ok()    { printf "\033[1;32m[OK]\033[0m    %s\n" "$1"; }
warn()  { printf "\033[1;33m[WARN]\033[0m  %s\n" "$1"; }
err()   { printf "\033[1;31m[ERROR]\033[0m %s\n" "$1"; }

command_exists() { command -v "$1" &>/dev/null; }

is_macos() { [[ "$(uname -s)" == "Darwin" ]]; }
is_linux() { [[ "$(uname -s)" == "Linux" ]]; }

arch() {
    local a
    a="$(uname -m)"
    case "$a" in
        x86_64|amd64) echo "x86_64" ;;
        aarch64|arm64) echo "aarch64" ;;
        *) err "Unsupported architecture: $a"; exit 1 ;;
    esac
}

has_brew() { command_exists brew; }

ensure_path() {
    if [[ ":$PATH:" != *":$LOCAL_BIN:"* ]]; then
        export PATH="$LOCAL_BIN:$PATH"
    fi
}

# ---------------------------------------------------------------------------
# shared conda tools env
# ---------------------------------------------------------------------------
# Some tools (tmux, chafa) have no static Linux binary distribution, so conda
# is the only no-root install path on HPC. Rather than installing into
# whatever env happens to be active (base, or a work env), they go into one
# dedicated env, and only the binary gets symlinked into ~/.local/bin. That
# way these tools are on PATH regardless of which conda env (if any) you have
# active for actual work, and you never touch base or a work env.

CONDA_TOOLS_ENV="dotfiles-tools"

conda_tools_env_path() {
    conda env list | grep -E "^${CONDA_TOOLS_ENV}\s" | awk '{print $NF}'
}

# install_via_conda_tools_env <conda-package> [binary-name, default = package]
install_via_conda_tools_env() {
    local pkg="$1"
    local bin="${2:-$1}"

    if ! conda env list | grep -qE "^${CONDA_TOOLS_ENV}\s"; then
        info "Creating conda env '$CONDA_TOOLS_ENV' for $pkg..."
        conda create -y -n "$CONDA_TOOLS_ENV" -c conda-forge "$pkg"
    else
        local env_path
        env_path="$(conda_tools_env_path)"
        if [[ ! -x "$env_path/bin/$bin" ]]; then
            info "Installing $pkg into '$CONDA_TOOLS_ENV'..."
            conda install -y -n "$CONDA_TOOLS_ENV" -c conda-forge "$pkg"
        fi
    fi

    ln -sf "$(conda_tools_env_path)/bin/$bin" "$LOCAL_BIN/$bin"
}

# ---------------------------------------------------------------------------
# neovim
# ---------------------------------------------------------------------------

NVIM_MIN="0.11.0"   # minimum the config supports (native vim.lsp.config API)

install_nvim() {
    if command_exists nvim; then
        local current
        current="$(nvim --version | head -1 | sed 's/.*v\([0-9]*\.[0-9]*\.[0-9]*\).*/\1/')"
        # any version >= NVIM_MIN is fine; don't churn just because brew is newer
        if [[ "$(printf '%s\n' "$NVIM_MIN" "$current" | sort -V | head -1)" == "$NVIM_MIN" ]]; then
            ok "neovim $current already installed (>= $NVIM_MIN)"
            return
        fi
        warn "neovim $current found, need >= $NVIM_MIN, installing $NVIM_VERSION"
    fi

    info "Installing neovim $NVIM_VERSION..."

    if is_macos; then
        if has_brew; then
            brew install neovim
        else
            err "On macOS without Homebrew. Install brew first: https://brew.sh"
            exit 1
        fi
    else
        # release assets >= 0.11 are named nvim-linux-<arch>.appimage (arm uses arm64)
        local appimage_arch
        case "$(uname -m)" in
            x86_64|amd64) appimage_arch="x86_64" ;;
            aarch64|arm64) appimage_arch="arm64" ;;
            *) err "Unsupported architecture: $(uname -m)"; exit 1 ;;
        esac
        local nvim_url="https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux-${appimage_arch}.appimage"
        curl -fsSL "$nvim_url" -o "$LOCAL_BIN/nvim.appimage"
        chmod u+x "$LOCAL_BIN/nvim.appimage"

        # test if appimage runs (FUSE might not be available on HPC)
        if "$LOCAL_BIN/nvim.appimage" --version &>/dev/null; then
            ln -sf "$LOCAL_BIN/nvim.appimage" "$LOCAL_BIN/nvim"
        else
            warn "FUSE unavailable, extracting appimage..."
            cd "$LOCAL_BIN"
            ./nvim.appimage --appimage-extract &>/dev/null
            rm nvim.appimage
            mv squashfs-root "$HOME/.local/nvim-extracted"
            ln -sf "$HOME/.local/nvim-extracted/usr/bin/nvim" "$LOCAL_BIN/nvim"
            cd "$SCRIPT_DIR"
        fi
    fi
    ok "neovim installed"
}

# ---------------------------------------------------------------------------
# tmux
# ---------------------------------------------------------------------------

install_tmux() {
    if command_exists tmux; then
        local current
        current="$(tmux -V | sed 's/[^0-9.]//g')"
        if [[ "$(printf '%s\n' "$TMUX_VERSION" "$current" | sort -V | head -1)" == "$TMUX_VERSION" ]]; then
            ok "tmux $current already installed (>= $TMUX_VERSION)"
            return
        fi
        warn "tmux $current found, need >= $TMUX_VERSION"
    fi

    info "Installing tmux..."

    if is_macos; then
        if has_brew; then
            brew install tmux
        else
            err "On macOS without Homebrew."
            exit 1
        fi
    else
        # on linux HPC without root, conda is the easiest path for tmux
        # since there's no static binary distribution
        if command_exists conda; then
            install_via_conda_tools_env tmux
        elif command_exists apt-get; then
            info "Trying apt (may need sudo)..."
            sudo apt-get update && sudo apt-get install -y tmux
        else
            warn "Could not install tmux automatically."
            warn "Options: install via conda (conda install -c conda-forge tmux)"
            warn "  or ask your sysadmin to install it."
            return
        fi
    fi
    ok "tmux installed"
}

# ---------------------------------------------------------------------------
# ripgrep
# ---------------------------------------------------------------------------

install_ripgrep() {
    if command_exists rg; then
        ok "ripgrep already installed ($(rg --version | head -1))"
        return
    fi

    info "Installing ripgrep $RIPGREP_VERSION..."

    if is_macos; then
        if has_brew; then
            brew install ripgrep
        fi
    else
        local a
        a="$(arch)"
        local url="https://github.com/BurntSushi/ripgrep/releases/download/${RIPGREP_VERSION}/ripgrep-${RIPGREP_VERSION}-${a}-unknown-linux-musl.tar.gz"
        local tmp
        tmp="$(mktemp -d)"
        curl -fsSL "$url" -o "$tmp/rg.tar.gz"
        tar xzf "$tmp/rg.tar.gz" -C "$tmp"
        cp "$tmp"/ripgrep-*/rg "$LOCAL_BIN/"
        rm -rf "$tmp"
    fi
    ok "ripgrep installed"
}

# ---------------------------------------------------------------------------
# fd
# ---------------------------------------------------------------------------

install_fd() {
    if command_exists fd; then
        ok "fd already installed ($(fd --version))"
        return
    fi

    info "Installing fd $FD_VERSION..."

    if is_macos; then
        if has_brew; then
            brew install fd
        fi
    else
        local a
        a="$(arch)"
        local url="https://github.com/sharkdp/fd/releases/download/v${FD_VERSION}/fd-v${FD_VERSION}-${a}-unknown-linux-musl.tar.gz"
        local tmp
        tmp="$(mktemp -d)"
        curl -fsSL "$url" -o "$tmp/fd.tar.gz"
        tar xzf "$tmp/fd.tar.gz" -C "$tmp"
        cp "$tmp"/fd-*/fd "$LOCAL_BIN/"
        rm -rf "$tmp"
    fi
    ok "fd installed"
}

# ---------------------------------------------------------------------------
# chafa (terminal image viewer — renders images via the Kitty graphics
# protocol, which Ghostty supports, so `chafa image.png` shows real images
# over plain SSH, no X11 forwarding needed)
# ---------------------------------------------------------------------------

install_chafa() {
    if command_exists chafa; then
        ok "chafa already installed ($(chafa --version | head -1))"
        return
    fi

    info "Installing chafa..."

    if is_macos; then
        if has_brew; then
            brew install chafa
        fi
    else
        # like tmux, no static Linux binary distribution, so conda it is
        if command_exists conda; then
            install_via_conda_tools_env chafa
        else
            warn "Could not install chafa automatically (no conda found)."
            warn "Install via conda: conda install -c conda-forge chafa"
            return
        fi
    fi
    ok "chafa installed"
}

# ---------------------------------------------------------------------------
# nvm + node
# ---------------------------------------------------------------------------

install_node() {
    if command_exists node; then
        ok "node already installed ($(node --version))"
        return
    fi

    info "Installing nvm $NVM_VERSION + node LTS..."

    export NVM_DIR="$HOME/.nvm"

    if [[ ! -d "$NVM_DIR" ]]; then
        curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash
    fi

    # source nvm for this session
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    nvm install --lts
    nvm use --lts

    ok "node $(node --version) installed via nvm"
}

# ---------------------------------------------------------------------------
# configs
# ---------------------------------------------------------------------------

install_configs() {
    info "Installing configs..."

    # backup existing
    for f in "$HOME/.config/nvim/init.lua" "$HOME/.tmux.conf"; do
        if [[ -f "$f" ]]; then
            warn "Backing up $f -> ${f}.bak"
            cp "$f" "${f}.bak"
        fi
    done

    # purge old neovim state for a clean start
    info "Cleaning old neovim state..."
    rm -rf "$HOME/.local/share/nvim"
    rm -rf "$HOME/.local/state/nvim"
    rm -rf "$HOME/.cache/nvim"

    # neovim
    mkdir -p "$HOME/.config/nvim"
    cp "$SCRIPT_DIR/nvim/init.lua" "$HOME/.config/nvim/init.lua"
    ok "init.lua -> ~/.config/nvim/init.lua"

    # tmux
    cp "$SCRIPT_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf"
    ok ".tmux.conf -> ~/.tmux.conf"

    # ghostty (GUI terminal — only relevant on a local machine with a display,
    # so skip it on headless HPC nodes)
    if is_macos; then
        mkdir -p "$HOME/.config/ghostty"
        cp "$SCRIPT_DIR/ghostty/config" "$HOME/.config/ghostty/config"
        ok "ghostty config -> ~/.config/ghostty/config"
    fi

    # tpm
    if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
        info "Installing tpm..."
        git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
        ok "tpm installed"
    else
        ok "tpm already installed"
    fi
}

# ---------------------------------------------------------------------------
# shell config
# ---------------------------------------------------------------------------

ensure_shell_config() {
    local shell_rc
    if [[ -n "${ZSH_VERSION:-}" ]] || [[ "$SHELL" == */zsh ]]; then
        shell_rc="$HOME/.zshrc"
    else
        shell_rc="$HOME/.bashrc"
    fi

    local path_line='export PATH="$HOME/.local/bin:$PATH"'

    if ! grep -qF '.local/bin' "$shell_rc" 2>/dev/null; then
        info "Adding ~/.local/bin to PATH in $shell_rc"
        echo "" >> "$shell_rc"
        echo "# added by dotfiles setup" >> "$shell_rc"
        echo "$path_line" >> "$shell_rc"
        ok "PATH updated in $shell_rc"
    else
        ok "~/.local/bin already in PATH"
    fi

    # alias vim to nvim if not already
    if ! grep -qF 'alias vim=' "$shell_rc" 2>/dev/null; then
        echo 'alias vim="nvim"' >> "$shell_rc"
        ok "Added vim -> nvim alias"
    fi
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

main() {
    echo ""
    echo "=========================================="
    echo "  dotfiles setup"
    echo "=========================================="
    echo ""

    ensure_path

    install_nvim
    install_tmux
    install_ripgrep
    install_fd
    install_chafa
    install_node
    install_configs
    ensure_shell_config

    echo ""
    echo "=========================================="
    echo "  setup complete"
    echo "=========================================="
    echo ""
    echo "Next steps:"
    echo "  1. Restart your shell (or run: source ~/.bashrc)"
    echo "  2. Open nvim, wait for plugins to install"
    echo "  3. Run :checkhealth inside nvim"
    echo "  4. Start tmux, press Ctrl-Space + I to install tmux plugins"
    echo ""
}

main "$@"
