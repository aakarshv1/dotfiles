# dotfiles

Terminal-first dev environment: neovim + tmux + claude code.

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
