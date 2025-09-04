defmodule StudyBot.AI.Client do
  @moduledoc """
  Unified interface for AI providers (OpenAI, Anthropic).
  The provider is selected at compile time via application configuration.
  """

  @callback chat_completion(messages :: list(), opts :: map()) :: {:ok, String.t()} | {:error, any()}
  @callback generate_embedding(text :: String.t()) :: {:ok, list()} | {:error, any()}
  @callback get_embedding_model() :: String.t()
  @callback get_embedding_dimensions() :: integer()

  @provider Application.compile_env(:study_bot, :ai_provider, :openai)

  @doc """
  Get the configured AI provider client module.
  """
  def provider_module do
    case @provider do
      :openai -> StudyBot.AI.OpenAIClient
      :anthropic -> StudyBot.AI.AnthropicClient
    end
  end

  @doc """
  Generate a chat completion using the configured provider.
  """
  def chat_completion(messages, opts \\ %{}) do
    provider_module().chat_completion(messages, opts)
  end

  @doc """
  Generate an embedding for the given text.
  """
  def generate_embedding(text) do
    provider_module().generate_embedding(text)
  end

  @doc """
  Get the embedding model name for the configured provider.
  """
  def get_embedding_model do
    provider_module().get_embedding_model()
  end

  @doc """
  Get the embedding dimensions for the configured provider.
  """
  def get_embedding_dimensions do
    provider_module().get_embedding_dimensions()
  end
end