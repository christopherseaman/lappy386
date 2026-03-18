-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    vim.opt_local.tabstop = 4
    vim.opt_local.softtabstop = 4
    vim.opt_local.shiftwidth = 4
  end,
})

-- Hide tmux status bar while nvim is open
if vim.env.TMUX then
  vim.api.nvim_create_autocmd({ "VimEnter", "VimResume" }, {
    callback = function()
      vim.fn.system("tmux set status off")
    end,
  })
  vim.api.nvim_create_autocmd({ "VimLeave", "VimSuspend" }, {
    callback = function()
      vim.fn.system("tmux set status on")
    end,
  })
end

-- Copy to system clipboard via OSC 52 escape sequence (works over SSH/tmux)
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function()
    if vim.v.event.operator == "y" then
      local text = vim.fn.getreg('"')
      local base64 = vim.fn.system("base64", text):gsub("\n", "")
      io.write(string.format("\027]52;c;%s\007", base64))
    end
  end,
})
