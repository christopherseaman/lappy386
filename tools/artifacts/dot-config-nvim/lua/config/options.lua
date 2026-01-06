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
