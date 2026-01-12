-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Auto-reload files changed outside of Neovim
vim.o.autoread = true

-- Check for file changes when focusing Neovim or switching buffers
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold" }, {
  command = "checktime",
})

-- Soft-wrap long lines at word boundaries
vim.opt.wrap = true
vim.opt.linebreak = true

-- Tab and indentation settings
vim.o.tabstop = 2 -- A TAB character looks like 2 spaces
vim.o.expandtab = true -- Pressing the TAB key will insert spaces instead of a TAB character
vim.o.softtabstop = 2 -- Number of spaces inserted instead of a TAB character
vim.o.shiftwidth = 2 -- Number of spaces inserted when indenting
