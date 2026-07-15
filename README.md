# dotfiles

Terminal-first dev environment: neovim + tmux + claude code.

## Terminal app

On macOS, use **[Ghostty](https://ghostty.org)** rather than the built-in Terminal.app —
Terminal.app can't render 24-bit truecolor, so the catppuccin theme looks washed out.

```bash
brew install --cask ghostty font-jetbrains-mono-nerd-font
```

`setup.sh` copies `ghostty/config` to `~/.config/ghostty/config`. The Nerd Font is needed
for the statusline / which-key icons to render. (WezTerm and Kitty are good alternatives;
iTerm2 works but is heavier.)

## Install

```bash
git clone https://github.com/YOUR_USERNAME/dotfiles.git ~/dotfiles
cd ~/dotfiles
bash setup.sh
```

Re-running is safe. It skips anything already installed.

## What gets installed

| Tool     | Purpose                              | Install method            |
|----------|--------------------------------------|---------------------------|
| neovim   | Editor                               | appimage (Linux) / brew   |
| tmux     | Terminal multiplexer                  | conda / apt / brew        |
| ripgrep  | Fast grep (used by telescope)        | static binary / brew      |
| fd       | Fast find (used by telescope)        | static binary / brew      |
| nvm+node | JS runtime (needed by some LSPs)     | nvm                       |
| tpm      | Tmux plugin manager                  | git clone                 |

## Repo structure

```
dotfiles/
├── nvim/
│   └── init.lua          # neovim config (plugins, LSP, keybindings)
├── tmux/
│   └── .tmux.conf        # tmux config (prefix, appearance, plugins)
├── ghostty/
│   └── config            # ghostty terminal config (macOS)
├── setup.sh              # one-shot installer
├── CHEATSHEET.md         # vim + tmux quick reference
└── README.md
```

## Post-install

1. Restart your shell (or `source ~/.bashrc`)
2. Open `nvim`, wait for lazy.nvim to finish installing plugins
3. Run `:checkhealth` inside nvim to verify everything works
4. Start `tmux`, press `Ctrl-Space + I` to install tmux plugins

## Workflow

```bash
ssh cluster
tmux new -s work        # or: tmux attach -t work
# pane 1: nvim
# pane 2: claude code
# pane 3: shell (git, slurm, scripts)
```

## Customizing

The init.lua is a single file on purpose. Once you're comfortable, common
next steps are adding formatters (conform.nvim), a file tree (oil.nvim or
neo-tree), or splitting the config into modules under nvim/lua/.
