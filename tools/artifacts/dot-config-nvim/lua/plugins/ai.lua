return {
  -- Import LazyVim's Copilot extra (for completions)
  { import = "lazyvim.plugins.extras.ai.copilot" },

  -- Import LazyVim's Avante extra (for AI chat)
  { import = "lazyvim.plugins.extras.ai.avante" },

  -- Customize Avante if needed (this will override the extra's config)
  {
    "yetone/avante.nvim",
    opts = {
      provider = "copilot",
      auto_suggestions_provider = "copilot",
      -- No need for copilot.model or openai config when using Copilot provider
    },
  },
}
