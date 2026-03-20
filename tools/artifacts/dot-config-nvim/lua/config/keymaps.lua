-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Override LazyVim's default Tab behavior
vim.keymap.set("i", "<Tab>", function()
  -- First check for Copilot suggestions
  if package.loaded["copilot.suggestion"] and require("copilot.suggestion").is_visible() then
    require("copilot.suggestion").accept()
    return
  end

  -- Then check for active snippets
  if vim.snippet and vim.snippet.active({ direction = 1 }) then
    vim.snippet.jump(1)
    return
  end

  -- Then check for blink.cmp completion
  if package.loaded["blink.cmp"] then
    local blink = require("blink.cmp")
    if blink.is_visible() then
      blink.accept()
      return
    end
  end

  -- Finally, just insert a tab
  vim.api.nvim_feedkeys("\t", "n", false)
end, { desc = "Smart Tab" })

-- Easy terminal escape and window switching
vim.keymap.set("t", "<C-h>", "<C-\\><C-n><C-w>h", { desc = "Switch to left window" })
vim.keymap.set("t", "<C-l>", "<C-\\><C-n><C-w>l", { desc = "Switch to right window" })
