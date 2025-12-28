return {
  -- Import LazyVim's Copilot extra (for completions)
  { import = "lazyvim.plugins.extras.ai.copilot" },

  -- Make Copilot inline dismissable with <Esc> while staying in insert mode
  {
    "zbirenbaum/copilot.lua",
    opts = function(_, opts)
      opts.suggestion = vim.tbl_deep_extend("force", opts.suggestion or {}, {
        keymap = vim.tbl_extend("force", opts.suggestion and opts.suggestion.keymap or {}, {
          dismiss = "<Esc>",
        }),
      })
    end,
  },

  -- Import LazyVim's Avante extra (for AI chat)
  { import = "lazyvim.plugins.extras.ai.avante" },

  -- Customize Avante if needed (this will override the extra's config)
  {
    "yetone/avante.nvim",
    opts = {
      provider = "codex",
      -- acp_provider = "codex",
      -- acp_providers = {
      --   ["codex"] = {
      --     command = "npx",
      --     args = { "@zed-industries/codex-acp" },
      --     env = {
      --       NODE_NO_WARNINGS = "1",
      --     },
      --   },
      -- },
      -- provider = "copilot",
      -- No need for copilot.model or openai config when using Copilot provider
      auto_suggestions = false,
      -- auto_suggestions_provider = "copilot",
    },
  },
}
