# Configuration for using Anthropic Claude as the primary AI provider
# To use this config: `cp config/anthropic.exs config/dev_local.exs` (or appropriate env)
# Note: OpenAI API key is still required for embeddings since Anthropic doesn't provide embeddings

import Config

config :study_bot,
  ai_provider: :anthropic,
  openai_api_key: System.get_env("OPENAI_API_KEY"),      # Required for embeddings
  anthropic_api_key: System.get_env("ANTHROPIC_API_KEY") # Required for chat completions