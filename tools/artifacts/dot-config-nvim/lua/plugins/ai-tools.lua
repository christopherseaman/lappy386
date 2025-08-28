return {
  -- Copilot for autocomplete
  {
    "github/copilot.vim",
    config = function()
      -- Enable inline suggestions (ghost text)
      vim.g.copilot_enabled = true
      
      -- Disable Copilot in specific filetypes
      vim.g.copilot_filetypes = {
        ["*"] = true,  -- Enable for all by default
        ["gitcommit"] = false,
        ["TelescopePrompt"] = false,
        ["neo-tree"] = false,
      }
      
      -- Navigation keys for cycling through multiple suggestions
      vim.keymap.set('i', '<M-]>', '<Plug>(copilot-next)', { silent = true })
      vim.keymap.set('i', '<M-[>', '<Plug>(copilot-previous)', { silent = true })
      
      -- Esc dismisses inline suggestions instead of accepting them
      vim.keymap.set("i", "<Esc>", function()
        if vim.fn["copilot#GetDisplayedSuggestion"]() ~= "" then
          vim.fn["copilot#Dismiss"]()
          return ""
        else
          return "<Esc>"
        end
      end, { expr = true, silent = true })
    end,
  },
  -- Official Claude Code integration (most advanced)
  {
    "coder/claudecode.nvim",
    dependencies = { "folke/snacks.nvim" },
    opts = {},
  },
}
