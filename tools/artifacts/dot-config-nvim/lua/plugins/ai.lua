return {
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

  -- -- Avante: use Claude with Max subscription
  -- {
  --   "yetone/avante.nvim",
  --   opts = {
  --     provider = "claude",
  --     providers = {
  --       claude = {
  --         auth_type = "max",
  --         model = "claude-opus-4-6",
  --       },
  --     },
  --   },
  -- },
}
