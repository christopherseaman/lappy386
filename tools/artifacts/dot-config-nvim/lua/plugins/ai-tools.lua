return {
  -- Copilot.lua - more modern Copilot integration with ghost text
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "InsertEnter",
    config = function()
      require("copilot").setup({
        panel = {
          enabled = true,
          auto_refresh = false,
          keymap = {
            jump_prev = "[[",
            jump_next = "]]",
            accept = "<CR>",
            refresh = "gr",
            open = "<M-CR>",
          },
          layout = {
            position = "bottom", -- | top | left | right
            ratio = 0.4,
          },
        },
        suggestion = {
          enabled = true,  -- This enables ghost text suggestions
          auto_trigger = true,
          debounce = 75,
          keymap = {
            accept = "<Tab>",
            accept_word = false,
            accept_line = false,
            next = "<M-]>",
            prev = "<M-[>",
            dismiss = "<C-]>",
          },
        },
        filetypes = {
          ["*"] = true,
          gitcommit = false,
          TelescopePrompt = false,
          ["neo-tree"] = false,
        },
        copilot_node_command = "node",
        server_opts_overrides = {},
      })
    end,
  },
  
  -- Official Claude Code integration (most advanced)
  {
    "coder/claudecode.nvim",
    dependencies = { "folke/snacks.nvim" },
    opts = {},
  },
}
