return {
  -- Import LazyVim's Copilot extra (now under ai, not coding)
  { import = "lazyvim.plugins.extras.ai.copilot" },

  -- Import LazyVim's Avante extra
  { import = "lazyvim.plugins.extras.ai.avante" },

  -- Configure Avante to use Claude Code via ACP
  -- Uses existing Claude Code auth from ~/.claude/config.json
  {
    "yetone/avante.nvim",
    opts = {
      provider = "claude-code",
      acp_providers = {
        ["claude-code"] = {
          command = "npx",
          args = { "@zed-industries/claude-code-acp" },
          env = {
            NODE_NO_WARNINGS = "1",
          },
        },
      },
    },
  },
}
