return {
  -- UI & Navigation
  { "nvim-lualine/lualine.nvim", config = true },
  { "nvim-tree/nvim-tree.lua", config = true },
  { "nvim-telescope/telescope.nvim", dependencies = { "nvim-lua/plenary.nvim" } },

  -- Git
  { "TimUntersberger/neogit", dependencies = { "nvim-lua/plenary.nvim" }, config = true },

  -- LSP and Tools
  { "neovim/nvim-lspconfig" },
  { "williamboman/mason.nvim", config = true },
  { "williamboman/mason-lspconfig.nvim" },

  -- Completion
  { "hrsh7th/nvim-cmp" },
  { "hrsh7th/cmp-nvim-lsp" },
  { "L3MON4D3/LuaSnip" },

  -- Syntax Highlighting
  -- LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Configure Tree-sitter to install and highlight the C++ parser. 2026-09-02.
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = { "c", "cpp", "rust", "typescript", "lua" },
        highlight = { enable = true },
        indent = { enable = true },
      })
    end,
  },
  -- LLM PROMPT [end]

  -- ⟢RustyChan🦀
  {
  'mrcjkb/rustaceanvim',
  version = '^6', -- Recommended
  lazy = false, -- This plugin is already lazy
  }
}
