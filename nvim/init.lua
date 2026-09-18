require("config.lazy")
-- LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Load the rest of the Neovim Lua config and enable true-color syntax/filetype support. 2026-09-02.
require("init")

-- my pref
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.termguicolors = true
vim.cmd("filetype plugin indent on")
vim.cmd("syntax enable")
-- LLM PROMPT [end]
