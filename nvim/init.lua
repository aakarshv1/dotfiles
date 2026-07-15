-- =============================================================================
-- NEOVIM INIT.LUA — Starter config for terminal-first HPC workflow
-- =============================================================================
--
-- Installation:
--   1. Install neovim 0.10+ (https://github.com/neovim/neovim/releases)
--   2. Copy this directory to ~/.config/nvim/
--   3. Open nvim — lazy.nvim will auto-install all plugins on first launch
--   4. Run :checkhealth to verify everything is working
--
-- Dependencies (install on your system):
--   - ripgrep (rg)  — used by telescope for live grep
--   - fd             — used by telescope for file finding
--   - a nerdfont     — for icons (optional, looks nice in tmux too)
--   - node           — needed by some LSP servers
--   - python3 + pip  — for pyright: pip install pyright
--
-- =============================================================================


-- ---------------------------------------------------------------------------
-- 1. CORE OPTIONS
-- ---------------------------------------------------------------------------
-- These are vanilla neovim settings, no plugins needed. They make the editor
-- behave sanely out of the box.

vim.g.mapleader = " "       -- spacebar as leader key (most ergonomic, used by nearly every modern config)
vim.g.maplocalleader = " "

vim.opt.number = true         -- line numbers
vim.opt.relativenumber = true -- relative line numbers (makes j/k jumping intuitive: "5j" to go 5 lines down)
vim.opt.cursorline = true     -- highlight current line
vim.opt.signcolumn = "yes"    -- always show sign column (prevents layout shift from LSP diagnostics)

vim.opt.tabstop = 4           -- tabs display as 4 spaces
vim.opt.shiftwidth = 4        -- indent by 4 spaces
vim.opt.expandtab = true      -- use spaces, not tabs (critical for python)
vim.opt.smartindent = true

vim.opt.wrap = false          -- don't wrap long lines (scroll instead)
vim.opt.scrolloff = 8         -- keep 8 lines visible above/below cursor
vim.opt.sidescrolloff = 8

vim.opt.ignorecase = true     -- case-insensitive search...
vim.opt.smartcase = true      -- ...unless you type a capital letter

vim.opt.splitright = true     -- new vertical splits open right
vim.opt.splitbelow = true     -- new horizontal splits open below

vim.opt.undofile = true       -- persistent undo across sessions (stored in ~/.local/state/nvim/undo)
vim.opt.swapfile = false      -- swap files cause more annoyance than they prevent on HPC

vim.opt.termguicolors = true  -- 24-bit color (required for modern colorschemes)
vim.opt.updatetime = 250      -- faster CursorHold events (used by gitsigns, LSP hover)
vim.opt.timeoutlen = 300      -- faster key sequence completion

vim.opt.clipboard = "unnamedplus" -- yank/paste uses system clipboard


-- ---------------------------------------------------------------------------
-- 2. KEYMAPS (plugin-independent)
-- ---------------------------------------------------------------------------
-- These are the keybindings you'll use constantly. Keeping them here rather
-- than scattered across plugin configs makes them easy to find and change.

local map = vim.keymap.set

-- window navigation (Ctrl+hjkl instead of Ctrl-W then hjkl)
map("n", "<C-h>", "<C-w>h")
map("n", "<C-j>", "<C-w>j")
map("n", "<C-k>", "<C-w>k")
map("n", "<C-l>", "<C-w>l")

-- move selected lines up/down in visual mode
map("v", "J", ":m '>+1<CR>gv=gv")
map("v", "K", ":m '<-2<CR>gv=gv")

-- keep cursor centered when scrolling
map("n", "<C-d>", "<C-d>zz")
map("n", "<C-u>", "<C-u>zz")

-- keep cursor centered when jumping through search results
map("n", "n", "nzzzv")
map("n", "N", "Nzzzv")

-- quick save
map("n", "<leader>w", "<cmd>w<CR>")

-- clear search highlight
map("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- diagnostic navigation
map("n", "[d", vim.diagnostic.goto_prev)
map("n", "]d", vim.diagnostic.goto_next)
map("n", "<leader>e", vim.diagnostic.open_float)


-- ---------------------------------------------------------------------------
-- 3. PLUGIN MANAGER: lazy.nvim
-- ---------------------------------------------------------------------------
-- WHY lazy.nvim over alternatives:
--   - packer.nvim: deprecated, author recommends lazy.nvim
--   - vim-plug: vimscript-based, no lazy-loading, slower
--   - lazy.nvim: fastest startup, automatic lazy-loading, lockfile for
--     reproducibility, great UI (:Lazy), written in Lua
--
-- This block auto-installs lazy.nvim if it's not already present.

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        "git", "clone", "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable",
        lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)


-- ---------------------------------------------------------------------------
-- 4. PLUGINS
-- ---------------------------------------------------------------------------

require("lazy").setup({

    -- ======================================================================
    -- COLORSCHEME: catppuccin
    -- ======================================================================
    -- WHY catppuccin over alternatives:
    --   - gruvbox: great but very warm/brown, less readable for long sessions
    --   - tokyonight: solid but overused, catppuccin has better contrast tuning
    --   - onedark: fine but limited variants
    --   - catppuccin: 4 flavors (latte/frappe/macchiato/mocha), extensive
    --     plugin integrations (telescope, treesitter, gitsigns all get themed),
    --     easy on eyes for long coding sessions, excellent terminal colors
    {
        "catppuccin/nvim",
        name = "catppuccin",
        priority = 1000, -- load before other plugins so colors are available
        config = function()
            require("catppuccin").setup({
                flavour = "mocha", -- darkest variant, good for terminal
            })
            vim.cmd.colorscheme("catppuccin")
        end,
    },

    -- ======================================================================
    -- FUZZY FINDER: telescope.nvim
    -- ======================================================================
    -- WHY telescope over alternatives:
    --   - fzf.vim: fast but limited UI, harder to extend
    --   - fzf-lua: very fast, good alternative if telescope feels slow
    --   - telescope: best plugin ecosystem (LSP pickers, git pickers, etc.),
    --     beautiful UI, highly extensible, de facto standard
    --
    -- This replaces VS Code's Ctrl+P (find files) and Ctrl+Shift+F (search).
    {
        "nvim-telescope/telescope.nvim",
        branch = "0.1.x",
        dependencies = {
            "nvim-lua/plenary.nvim",
            -- native fzf sorter for telescope (C implementation, much faster)
            { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
        },
        config = function()
            local telescope = require("telescope")
            telescope.setup({
                defaults = {
                    -- ripgrep flags: follow symlinks, show hidden files, respect .gitignore
                    vimgrep_arguments = {
                        "rg", "--color=never", "--no-heading", "--with-filename",
                        "--line-number", "--column", "--smart-case", "--follow",
                    },
                },
            })
            telescope.load_extension("fzf")

            local builtin = require("telescope.builtin")
            map("n", "<leader>ff", builtin.find_files)        -- find files by name
            map("n", "<leader>fg", builtin.live_grep)         -- search file contents (ripgrep)
            map("n", "<leader>fb", builtin.buffers)           -- switch between open buffers
            map("n", "<leader>fh", builtin.help_tags)         -- search neovim help
            map("n", "<leader>fr", builtin.oldfiles)          -- recently opened files
            map("n", "<leader>fd", builtin.diagnostics)       -- LSP diagnostics across project
            map("n", "<leader>fs", builtin.lsp_document_symbols) -- symbols in current file
        end,
    },

    -- ======================================================================
    -- SYNTAX: treesitter
    -- ======================================================================
    -- WHY treesitter over regex-based highlighting:
    --   - regex highlighting breaks constantly on complex code
    --   - treesitter parses actual ASTs, so highlighting is always correct
    --   - also powers incremental selection, text objects, code folding
    --   - makes python, lua, bash, C++, CUDA all look great out of the box
    {
        "nvim-treesitter/nvim-treesitter",
        branch = "master", -- the 'main' branch is an in-progress rewrite that drops the
                           -- classic require('nvim-treesitter.configs').setup() API used below
        build = ":TSUpdate",
        config = function()
            require("nvim-treesitter.configs").setup({
                ensure_installed = {
                    "python", "lua", "bash", "c", "cpp", "cuda",
                    "json", "yaml", "toml", "markdown", "markdown_inline",
                    "vim", "vimdoc", "regex",
                },
                highlight = { enable = true },
                indent = { enable = true },
                -- incremental selection: press Enter to expand selection by AST node
                -- (e.g., variable -> expression -> statement -> function -> file)
                incremental_selection = {
                    enable = true,
                    keymaps = {
                        init_selection = "<CR>",
                        node_incremental = "<CR>",
                        node_decremental = "<BS>",
                    },
                },
            })
        end,
    },

    -- ======================================================================
    -- LSP: language server protocol
    -- ======================================================================
    -- Neovim 0.11+ ships a native LSP config API (vim.lsp.config / vim.lsp.enable),
    -- but it does NOT ship the per-server definitions (cmd, filetypes, root markers).
    -- Those still come from the nvim-lspconfig plugin, which now provides them as
    -- runtime lsp/*.lua files that the native API consumes. So the modern stack is:
    --   - nvim-lspconfig : server definitions (no more lspconfig[server].setup{} calls)
    --   - mason          : portably installs the server binaries (pyright, clangd, ...)
    --   - mason-lspconfig: installs the servers via mason and auto-enables them
    --
    -- WHY this over alternatives:
    --   - coc.nvim: heavier, node.js dependency, its own plugin ecosystem
    --   - ale: linting only, no full LSP support

    -- mason: portable LSP/formatter/linter installer
    {
        "williamboman/mason.nvim",
        config = function()
            require("mason").setup()
        end,
    },

    -- mason-lspconfig: installs the servers listed below and, via its default
    -- automatic_enable, calls vim.lsp.enable() for each once installed.
    -- (Server names here are lspconfig names, e.g. lua_ls, not mason package names.)
    {
        "williamboman/mason-lspconfig.nvim",
        dependencies = {
            "williamboman/mason.nvim",
            "neovim/nvim-lspconfig", -- provides the per-server definitions
        },
        config = function()
            require("mason-lspconfig").setup({
                ensure_installed = { "pyright", "lua_ls", "clangd", "bashls", "ruff" },
            })
        end,
    },

    -- ======================================================================
    -- AUTOCOMPLETION: nvim-cmp
    -- ======================================================================
    -- WHY nvim-cmp over alternatives:
    --   - coq_nvim: fast but opinionated, harder to configure
    --   - nvim-cmp: modular source system (LSP, buffer, path, snippets all
    --     pluggable), most popular, best documented, very configurable
    {
        "hrsh7th/nvim-cmp",
        dependencies = {
            "hrsh7th/cmp-nvim-lsp",  -- LSP completions
            "hrsh7th/cmp-buffer",    -- words from current buffer
            "hrsh7th/cmp-path",      -- filesystem paths
            "L3MON4D3/LuaSnip",     -- snippet engine (required by cmp)
            "saadparwaiz1/cmp_luasnip",
        },
        config = function()
            local cmp = require("cmp")
            local luasnip = require("luasnip")

            cmp.setup({
                snippet = {
                    expand = function(args)
                        luasnip.lsp_expand(args.body)
                    end,
                },
                mapping = cmp.mapping.preset.insert({
                    ["<C-n>"] = cmp.mapping.select_next_item(),
                    ["<C-p>"] = cmp.mapping.select_prev_item(),
                    ["<C-Space>"] = cmp.mapping.complete(),       -- manually trigger completion
                    ["<CR>"] = cmp.mapping.confirm({ select = true }), -- accept selected
                    ["<C-e>"] = cmp.mapping.abort(),              -- dismiss menu
                }),
                sources = cmp.config.sources({
                    { name = "nvim_lsp" },  -- LSP completions first priority
                    { name = "luasnip" },
                }, {
                    { name = "buffer" },    -- fallback to buffer words
                    { name = "path" },
                }),
            })
        end,
    },

    -- ======================================================================
    -- GIT: gitsigns
    -- ======================================================================
    -- WHY gitsigns over alternatives:
    --   - vim-gitgutter: vimscript, slower, fewer features
    --   - vim-fugitive: complementary (full git UI), but gitsigns handles
    --     the in-buffer annotations (added/modified/deleted lines in gutter)
    --   - gitsigns: async, fast, inline blame, hunk staging from inside nvim
    {
        "lewis6991/gitsigns.nvim",
        config = function()
            require("gitsigns").setup({
                on_attach = function(bufnr)
                    local gs = require("gitsigns")
                    local opts = { buffer = bufnr }
                    map("n", "]c", gs.next_hunk, opts)     -- jump to next changed hunk
                    map("n", "[c", gs.prev_hunk, opts)     -- jump to prev changed hunk
                    map("n", "<leader>hs", gs.stage_hunk, opts)
                    map("n", "<leader>hr", gs.reset_hunk, opts)
                    map("n", "<leader>hb", gs.blame_line, opts)
                    map("n", "<leader>hp", gs.preview_hunk, opts)
                end,
            })
        end,
    },

    -- ======================================================================
    -- STATUSLINE: lualine
    -- ======================================================================
    -- WHY lualine over alternatives:
    --   - vim-airline: vimscript, slow, heavy
    --   - feline: more customizable but more setup
    --   - lualine: fast, good defaults, auto-integrates with catppuccin/lsp/git
    {
        "nvim-lualine/lualine.nvim",
        config = function()
            require("lualine").setup({
                options = {
                    -- "auto" derives the statusline colors from the active colorscheme.
                    -- (catppuccin ships flavour-specific themes like "catppuccin-mocha",
                    -- not a plain "catppuccin", so "auto" is the robust choice.)
                    theme = "auto",
                    section_separators = "",    -- clean look, no powerline arrows
                    component_separators = "",
                },
                sections = {
                    lualine_a = { "mode" },
                    lualine_b = { "branch", "diff", "diagnostics" },
                    lualine_c = { { "filename", path = 1 } }, -- show relative path
                    lualine_x = { "filetype" },
                    lualine_y = { "progress" },
                    lualine_z = { "location" },
                },
            })
        end,
    },

    -- ======================================================================
    -- AUTOPAIRS: auto-close brackets/quotes
    -- ======================================================================
    {
        "windwp/nvim-autopairs",
        event = "InsertEnter",
        config = true, -- default config is fine
    },

    -- ======================================================================
    -- COMMENT: toggle comments with gcc / gc in visual mode
    -- ======================================================================
    -- Built into neovim 0.10+ but this plugin handles edge cases better
    -- and works with treesitter for mixed-language files (e.g., HTML+JS)
    {
        "numToStr/Comment.nvim",
        config = true,
    },

    -- ======================================================================
    -- WHICH-KEY: shows available keybindings as you type
    -- ======================================================================
    -- Invaluable when learning. Press <leader> and wait, it shows all
    -- leader keybindings. Remove this once you've internalized the bindings.
    {
        "folke/which-key.nvim",
        event = "VeryLazy",
        config = true,
    },

}, {
    -- lazy.nvim options
    checker = { enabled = false }, -- don't auto-check for plugin updates on HPC
    change_detection = { notify = false },
})


-- ---------------------------------------------------------------------------
-- 5. LSP CONFIGURATION (neovim 0.11+ native API)
-- ---------------------------------------------------------------------------
-- mason-lspconfig (section 4) installs and enables the servers. Here we only
-- need two things the plugin doesn't do for us:
--   1. keymaps, set via an autocmd that fires when any server attaches
--   2. per-server setting overrides via vim.lsp.config(), which merge onto the
--      base definitions that nvim-lspconfig provides
-- Servers we don't override (pyright, clangd, bashls, ruff) need no entry here;
-- their defaults are correct out of the box.

-- LSP keymaps (set once when any server attaches to a buffer)
vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(args)
        local opts = { buffer = args.buf }
        map("n", "gd", vim.lsp.buf.definition, opts)
        map("n", "gr", vim.lsp.buf.references, opts)
        map("n", "gI", vim.lsp.buf.implementation, opts)
        map("n", "K", vim.lsp.buf.hover, opts)
        map("n", "<leader>rn", vim.lsp.buf.rename, opts)
        map("n", "<leader>ca", vim.lsp.buf.code_action, opts)
        map("n", "<leader>D", vim.lsp.buf.type_definition, opts)
    end,
})

-- lua_ls override: teach it about the LuaJIT runtime and neovim's own lua API
-- so editing this config doesn't flood you with "undefined global vim" warnings
vim.lsp.config("lua_ls", {
    settings = {
        Lua = {
            runtime = { version = "LuaJIT" },
            workspace = { library = vim.api.nvim_get_runtime_file("", true) },
        },
    },
})
