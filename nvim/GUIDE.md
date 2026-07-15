# Neovim: A Crash Course for Your Config

A guided tour of *your* setup — what every plugin does, the keybindings you have,
and how the machinery works under the hood. Written for someone who knows a little
vim and is coming from VS Code.

> Companion to `CHEATSHEET.md` (quick key reference). This file is the "why & how".

---

## 0. The one mental-model shift from VS Code

In VS Code you have an editor that you occasionally type commands into.
In (neo)vim, **you have a language for editing, and typing text is just one mode of it.**

Editing is composed of **verbs + motions + text objects**:

```
verb   motion/textobject
 d        w           → delete word
 c        i"          → change inside quotes
 y        ap          → yank a paragraph
 d        2j          → delete this line + 2 below
 >        ip          → indent inside paragraph
```

Once this clicks, you stop thinking "select-then-act" (mouse brain) and start
thinking "act-on-a-thing" (vim brain). This is the entire payoff. Everything else
in this doc is convenience on top of that core idea.

**Modes you'll live in:**

| Mode | How you enter | What it's for |
|------|---------------|---------------|
| Normal | `Esc` (home base) | navigate + run commands. You're here most of the time. |
| Insert | `i` `a` `o` `I` `A` `O` | actually typing text |
| Visual | `v` `V` `Ctrl-v` | selecting (char / line / block) |
| Command | `:` | ex-commands (`:w`, `:q`, `:Telescope`, …) |

The single most important habit: **return to Normal mode the instant you stop typing.**

---

## 1. How your config is structured

Everything lives in one file: `~/.config/nvim/init.lua` (copied from
`dotfiles/nvim/init.lua` by `setup.sh`). It has 5 sections:

1. **Core options** — vanilla settings, no plugins (line numbers, tabs, search…)
2. **Keymaps** — plugin-independent shortcuts
3. **Plugin manager** (lazy.nvim) — bootstraps itself
4. **Plugins** — the big `require("lazy").setup({ ... })` block
5. **LSP config** — keymaps-on-attach + per-server overrides

`<leader>` is the **spacebar** in your config. So "`<leader>ff`" means *press space,
then f, then f*. Leader is a namespace for your custom commands so they don't
collide with built-in keys.

---

## 2. Plugin manager: lazy.nvim

**What it is:** the thing that downloads, updates, and loads all other plugins.

**Under the hood:** plugins are just git repos. lazy.nvim clones each one into
`~/.local/share/nvim/lazy/<plugin>`, and adds it to Neovim's *runtimepath* (the list
of directories Neovim searches for Lua/vim files). "Lazy" = it can defer loading a
plugin until it's actually needed (on a keypress, a filetype, an event), which keeps
startup fast.

Each `{ "author/repo", ... }` entry is a **plugin spec**. Useful keys you'll see:
- `dependencies` — load these first
- `config = function() ... end` — run this after the plugin loads (its setup)
- `event` / `ft` / `cmd` — lazy-load triggers (e.g. `event = "InsertEnter"`)
- `build` — a shell/vim command to run on install (e.g. compiling something)

**Commands:**
- `:Lazy` — open the dashboard (see what's installed, load times, errors)
- `:Lazy sync` — install missing + update + clean removed plugins
- `:Lazy profile` — see what's slow at startup

`lazy-lock.json` pins exact versions so your setup is reproducible across machines.
Commit it.

---

## 3. The plugins, grouped by what they replace in VS Code

### 3a. Colorscheme — catppuccin
Just theming. `flavour = "mocha"` is the dark variant. It themes not just code but
telescope, the statusline, git signs, etc. (Your terminal Ghostty uses a matching
"Catppuccin Mocha" theme so everything is consistent.)

### 3b. Fuzzy finder — telescope.nvim  *(VS Code's Ctrl-P and Ctrl-Shift-F)*
This is the plugin you'll use constantly. A fuzzy picker over anything.

| Key | Does | VS Code equivalent |
|-----|------|--------------------|
| `<leader>ff` | find files by name | Ctrl-P |
| `<leader>fg` | live grep (search file *contents*) | Ctrl-Shift-F |
| `<leader>fb` | switch open buffers | tab list |
| `<leader>fr` | recently opened files | — |
| `<leader>fh` | search Neovim's help docs | — |
| `<leader>fd` | all LSP diagnostics in the project | Problems panel |
| `<leader>fs` | symbols in current file | Ctrl-Shift-O |

Inside a picker: type to filter, `Ctrl-n`/`Ctrl-p` (or arrows) to move, `Enter` to
open, `Ctrl-v`/`Ctrl-x` to open in a vertical/horizontal split, `Esc` to close.

**Under the hood:** telescope shells out to `ripgrep` (`rg`) for grep and `fd` for
files (both installed by `setup.sh`), pipes results through a fuzzy sorter, and
renders the picker UI. `telescope-fzf-native` is a small C extension (compiled via
`make` on install) that makes the sorting much faster. `plenary.nvim` is a shared
Lua utility library many plugins depend on.

### 3c. Syntax engine — nvim-treesitter
**What it is:** real syntax understanding, not regex guessing.

**Under the hood:** Treesitter parses your file into an actual syntax tree (AST) using
a per-language grammar (compiled `.so` parsers it downloaded for python, lua, cpp,
cuda, etc.). Because it knows the real structure, highlighting is always correct, and
it powers structural features:

- **Incremental selection** — press `Enter` to grow the selection by one AST node
  (identifier → expression → statement → function → file), `Backspace` to shrink.
  Try it: cursor on a variable, tap `Enter` a few times and watch it expand outward.
- Better indentation and (eventually) folding.

`:TSUpdate` updates parsers. `branch = "master"` is pinned in your config because the
newer `main` branch is an in-progress rewrite with a different API.

### 3d. LSP — the IntelliSense engine  *(this is the big one)*
LSP = **Language Server Protocol**. Three plugins cooperate:

- **mason.nvim** — a package manager for *language servers* (the background programs
  that actually understand Python/C++/etc.). `:Mason` opens its UI. Think of it as
  "brew, but for dev tooling that Neovim talks to."
- **mason-lspconfig.nvim** — installs the servers you listed (`pyright`, `lua_ls`,
  `clangd`, `bashls`, `ruff`) and auto-enables them.
- **nvim-lspconfig** — ships the *definitions* (how to launch each server, what
  filetypes it handles, how to find the project root). Neovim has the LSP *client*
  built in; this provides the per-server recipes.

**Under the hood:** open a `.py` file → Neovim starts `pyright` as a child process →
they exchange JSON messages over stdin/stdout ("user's cursor is here, what's the
type?", "rename this symbol everywhere"). The editor stays in sync with a program
that genuinely understands your code.

Your servers: **pyright** (Python types/completion), **ruff** (fast Python
linting/formatting), **lua_ls** (for editing this config), **clangd** (C/C++/CUDA),
**bashls** (shell scripts).

LSP keys (active once a server attaches to the buffer):

| Key | Does |
|-----|------|
| `gd` | go to definition |
| `gr` | find references |
| `gI` | go to implementation |
| `K` | hover docs (press again to enter the popup) |
| `<leader>rn` | rename symbol (project-wide) |
| `<leader>ca` | code action (quick fixes, imports…) |
| `<leader>D` | go to type definition |
| `[d` / `]d` | previous / next diagnostic |
| `<leader>e` | show the diagnostic under the cursor in a float |

Useful commands: `:LspInfo` (what's attached), `:Mason` (manage servers),
`:checkhealth vim.lsp`.

### 3e. Autocompletion — nvim-cmp
The popup menu as you type. It's a *separate* plugin from LSP — cmp is the menu, LSP
is one of the things that feeds it suggestions.

**Sources** (configured in priority order): LSP → snippets (LuaSnip) → current-buffer
words → file paths.

Keys (insert mode):

| Key | Does |
|-----|------|
| `Ctrl-n` / `Ctrl-p` | next / previous suggestion |
| `Ctrl-Space` | manually trigger the menu |
| `Enter` | accept the selected one |
| `Ctrl-e` | dismiss the menu |

### 3f. Git — gitsigns.nvim  *(VS Code's gutter + inline blame)*
Shows added/changed/deleted lines in the sign column and lets you act on "hunks"
(contiguous changes) without leaving Neovim.

| Key | Does |
|-----|------|
| `]c` / `[c` | next / previous changed hunk |
| `<leader>hs` | stage the hunk |
| `<leader>hr` | reset (discard) the hunk |
| `<leader>hp` | preview the hunk's diff |
| `<leader>hb` | blame the current line |

### 3g. The quality-of-life trio
- **lualine** — the statusline (mode, branch, diagnostics, file, position). `"auto"`
  theme so it matches catppuccin.
- **nvim-autopairs** — typing `(` gives you `()` with the cursor inside. Lazy-loaded
  on `InsertEnter`.
- **Comment.nvim** — `gcc` toggles a line comment; `gc` in visual mode toggles a
  selection; `gc` + motion works too (e.g. `gcap` comments a paragraph). Treesitter-
  aware so it uses the right comment syntax even in mixed files.

### 3h. The training wheels — which-key.nvim
Press `<leader>` (space) and **pause** — a popup lists every key that can follow.
Invaluable while learning; you can remove it once the bindings are muscle memory.
Lazy-loaded on `VeryLazy` (after startup).

---

## 4. Your custom (non-plugin) keymaps

These are in section 2 of `init.lua` and work everywhere:

| Key | Mode | Does |
|-----|------|------|
| `Ctrl-h/j/k/l` | normal | move between window splits (no `Ctrl-w` prefix needed) |
| `J` / `K` | visual | move the selected lines down / up |
| `Ctrl-d` / `Ctrl-u` | normal | half-page down/up, **re-centered** |
| `n` / `N` | normal | next/prev search result, re-centered |
| `<leader>w` | normal | save |
| `Esc` | normal | clear search highlight |

---

## 5. Survival vim (if your motions are rusty)

**Move:** `h j k l` (left/down/up/right) · `w`/`b` word fwd/back · `0`/`$` line
start/end · `gg`/`G` top/bottom · `{`/`}` paragraph · `Ctrl-d`/`Ctrl-u` half-page ·
`%` matching bracket.

**Jump precisely:** `f<char>` jump to next char on line (`;` repeats) · `/text` search
forward (`n`/`N` to cycle) · `*` search word under cursor.

**Edit (verb + motion/textobject):** `d`elete · `c`hange (delete + insert) · `y`ank
(copy) · `p`aste · `>`/`<` indent · `.` **repeat last change** (hugely underrated).

**Text objects** (the noun): `iw`/`aw` word · `i"`/`a"` quotes · `i(`/`a(` parens ·
`ip`/`ap` paragraph · `it`/`at` HTML/XML tag. So `ci"` = "change inside quotes",
`dap` = "delete a paragraph", `yi(` = "yank inside parens".

**Undo/redo:** `u` undo · `Ctrl-r` redo. (You have persistent undo — it survives
closing the file.)

**Windows/buffers:** `:vsplit`/`:split` · `Ctrl-hjkl` to move between them (your
mapping) · `:bn`/`:bp` next/prev buffer · `<leader>fb` to pick one.

The killer combos to internalize first: `ciw` (change word), `ci"` / `ci(` (change
inside quotes/parens), `dd` (delete line), `.` (repeat), `<leader>ff` / `<leader>fg`
(find files / grep).

---

## 6. A realistic 2-week learning path

1. **Day 1–2:** Don't customize anything. Just edit real files. Force yourself to use
   `hjkl` and `Esc`. Run `vimtutor` once (it's ~30 min, built in — type `vimtutor`
   in your shell).
2. **Day 3–5:** Learn `<leader>ff` and `<leader>fg` cold — that's 80% of navigation.
   Add `ciw`, `ci"`, `dd`, `.` to your reflexes.
3. **Week 2:** LSP keys (`gd`, `gr`, `K`, `<leader>rn`, `<leader>ca`) and gitsigns.
   Start using visual mode `J`/`K` to move lines.
4. **Ongoing:** when you think "there must be a faster way to do X," there usually is —
   look it up, add it to muscle memory. Use which-key (`<space>` + pause) to discover.

Don't try to learn everything at once. The config has more than you need on day one;
that's fine.

---

## 7. When you want to change things

- Edit `dotfiles/nvim/init.lua` (your source of truth), then re-run `bash setup.sh`
  to deploy — **or** symlink it once so edits are live immediately:
  `ln -sf ~/dotfiles/nvim/init.lua ~/.config/nvim/init.lua`. (Symlinking is the usual
  dotfiles approach; `setup.sh` currently *copies*.)
- After editing, `:source $MYVIMRC` reloads it (or just restart nvim).
- Add a plugin: drop a new `{ "author/repo", config = ... }` spec into the
  `require("lazy").setup({ ... })` table, save, run `:Lazy sync`.
- Common next additions people make: `conform.nvim` (format-on-save),
  `oil.nvim` or `neo-tree` (file explorer), `flash.nvim` (jump anywhere on screen),
  `trouble.nvim` (nicer diagnostics list).

---

## 8. Resources worth your time

**Start here:**
- `vimtutor` — run it in your terminal. The canonical 30-minute intro. Do it once.
- `:help <topic>` — Neovim's built-in docs are excellent. `:help` for the index,
  `:help lsp`, `:help telescope`, etc. Searchable with `<leader>fh`.
- **`:Tutor`** inside Neovim — the modern, Neovim-flavored version of vimtutor.

**Best videos / courses:**
- **ThePrimeagen — "Vim As Your Editor"** (YouTube series). The clearest explanation
  of the verb+motion model and why vim is fast. Your config is heavily inspired by his
  style (centered scrolling, leader=space, telescope).
- **TJ DeVries** (a core Neovim maintainer) — "kickstart.nvim" video walkthrough. He
  literally explains a config very similar to yours, line by line. Start here for the
  "how the config works" angle.

**Reference / reading:**
- **kickstart.nvim** (github.com/nvim-lua/kickstart.nvim) — a well-commented single-
  file config. Great to read alongside yours; it makes many of the same choices.
- **"Learn Vim (the Smart Way)"** (github.com/iggredible/Learn-Vim) — free, thorough,
  well-paced book on motions/text objects/registers.
- **vim-be-good** (a game, installable via Neovim) — drills motions interactively.
- Each plugin's GitHub README is the authoritative reference (telescope, gitsigns,
  nvim-cmp all have great docs).

**When something breaks:**
- `:checkhealth` — diagnoses missing dependencies, broken LSP, treesitter issues.
- `:Lazy` — plugin errors and load times.
- `:messages` — see messages that scrolled past.

---

## TL;DR

Learn the **verb + motion + text object** language first — that's the whole game.
Lean on `<leader>ff` / `<leader>fg` for navigation, `gd`/`K`/`<leader>ca` for code
intelligence, and `<space>`+pause (which-key) to discover the rest. Run `vimtutor`
today, watch a TJ DeVries or Primeagen video this week, and edit real code daily.
