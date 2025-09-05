# Configuration for using OpenAI as the primary AI provider
# To use this config: `cp config/openai.exs config/dev_local.exs` (or appropriate env)

import Config

config :study_bot,
  ai_provider: :openai,
  openai_api_key: System.get_env("OPENAI_API_KEY"),
  # Optional, not used with OpenAI provider
  anthropic_api_key: System.get_env("ANTHROPIC_API_KEY")
