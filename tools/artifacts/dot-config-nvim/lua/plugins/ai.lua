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

  {
    "yetone/avante.nvim",
    optional = true,
    dependencies = {
      { "ColinKennedy/mega.cmdparse", dependencies = { "ColinKennedy/mega.logging" } },
    },
    opts = {
      -- Keep exactly one provider selection active.
      provider = "copilot",
      -- provider = "claude",
      -- provider = "codex",
      providers = {
        copilot = {
          model = "gpt-6-luna",
        },
        -- Claude Pro/Max: enable this block and the Claude provider selection.
        -- claude = {
        --   auth_type = "max",
        --   model = "claude-opus-5-5",
        -- },
      },
      -- Codex: install @agentclientprotocol/codex-acp, then enable this block
      -- and the Codex provider selection. Model selection is handled by ACP.
      -- acp_providers = {
      --   codex = {
      --     command = "codex-acp",
      --     args = {},
      --     env = {
      --       CODEX_PATH = vim.fn.exepath("codex"),
      --     },
      --   },
      -- },
    },
  },
}
