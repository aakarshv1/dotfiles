# Vim + Tmux Cheatsheet

## The Vim Mental Model

Vim commands follow a **verb + modifier + noun** grammar:

    d  i  w     →  delete inside word
    c  a  "     →  change around quotes
    y  i  {     →  yank inside braces
    >  i  p     →  indent inside paragraph

Verbs: d(delete), c(change), y(yank/copy), v(visual select), >(indent), <(dedent)
Modifiers: i(inside), a(around)
Nouns: w(word), s(sentence), p(paragraph), ", ', (, {, [, t(html tag)

Once you learn the grammar, you can *construct* commands you've never seen before.


## Essential Motions

    h j k l         ←  ↓  ↑  →
    w / b           next word / previous word
    e               end of word
    0 / $           start / end of line
    gg / G          top / bottom of file
    Ctrl-d / Ctrl-u half-page down / up
    { / }           prev / next paragraph
    %               matching bracket
    f{char}         jump forward to {char} on current line
    ;               repeat last f/t motion


## Core Editing

    i / a           insert before / after cursor
    I / A           insert at line start / end
    o / O           new line below / above
    x               delete character
    dd / yy         delete / yank whole line
    p / P           paste after / before
    u / Ctrl-r      undo / redo
    .               repeat last change (extremely powerful)
    ciw             change entire word (use this constantly)
    ci" / ci( / ci{ change inside quotes / parens / braces


## Visual Mode

    v               character-wise visual
    V               line-wise visual
    Ctrl-v          block/column visual (multi-cursor equivalent)
    After selecting: d, y, c, >, <, = (format)


## Search and Replace

    /pattern        search forward
    ?pattern        search backward
    n / N           next / previous match
    *               search for word under cursor
    :%s/old/new/g   replace all in file
    :%s/old/new/gc  replace all with confirmation


## Leader Keybindings (Space = leader)

    <leader>ff      find files (telescope)
    <leader>fg      grep across files (telescope)
    <leader>fb      switch buffers
    <leader>fr      recent files
    <leader>fd      diagnostics
    <leader>fs      document symbols
    <leader>w       save file
    <leader>e       show diagnostic float
    <leader>rn      rename symbol (LSP)
    <leader>ca      code action (LSP)

    gd              go to definition
    gr              find references
    K               hover docs
    [d / ]d         prev / next diagnostic


## Git (gitsigns)

    ]c / [c         next / prev changed hunk
    <leader>hs      stage hunk
    <leader>hr      reset hunk
    <leader>hb      blame current line
    <leader>hp      preview hunk


## Tmux (prefix = Ctrl-Space)

    prefix |        vertical split
    prefix -        horizontal split
    prefix h/j/k/l  navigate panes
    prefix c        new window
    prefix 1-9      switch to window N
    prefix d        detach session
    prefix r        reload config
    prefix z        toggle pane zoom (fullscreen a pane)
    prefix [        enter scroll/copy mode (q to exit)

    tmux new -s dev         create named session
    tmux attach -t dev      reattach to session
    tmux ls                 list sessions

    prefix Ctrl-s           save session (resurrect)
    prefix Ctrl-r           restore session (resurrect)


## Python LSP + venvs (pyright)

pyright resolves imports from the active interpreter. If it can't find a venv it
falls back to system python and flags "unresolved import" for installed packages.
uv always creates the venv at `<project>/.venv`. Three ways to point pyright at it:

    source .venv/bin/activate && nvim    # per-launch; pyright honors $VIRTUAL_ENV
    [tool.pyright] in pyproject.toml      # per-project, editor-agnostic:
        venvPath = "."
        venv = ".venv"

Best: auto-detect once in init.lua so no per-project config is needed:

    vim.lsp.config("pyright", {
        on_init = function(client)
            local root = client.config.root_dir
            local venv_py = root and (root .. "/.venv/bin/python")
            if venv_py and vim.uv.fs_stat(venv_py) then
                client.settings = vim.tbl_deep_extend("force", client.settings or {}, {
                    python = { pythonPath = venv_py },
                })
                client.notify("workspace/didChangeConfiguration", { settings = client.settings })
            end
        end,
    })

After changing interpreter/config: :LspRestart


## Recommended Daily Workflow

    ssh cluster
    tmux new -s work                  # or tmux attach -t work
    # pane 1: nvim (your editor)
    # pane 2: claude code (AI assistant)
    # pane 3: shell (run scripts, git, slurm)


## Week 1 Learning Plan

    Day 1: vimtutor (run it twice)
    Day 2: hjkl, w/b, i/a/o, dd/yy/p, /search
    Day 3: ci{motion} family (ciw, ci", ci(, etc.)
    Day 4: telescope (leader+ff, leader+fg)
    Day 5: visual mode + block select (Ctrl-v)
    Day 6: splits, buffers, tmux pane workflow
    Day 7: LSP features (gd, gr, K, leader+rn)
    After: one new trick per day (macros, marks, registers, text objects)
