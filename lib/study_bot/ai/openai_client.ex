defmodule StudyBot.AI.OpenAIClient do
  @moduledoc """
  OpenAI API client implementation.
  """

  @behaviour StudyBot.AI.Client

  require Logger

  @embedding_model "text-embedding-ada-002"
  @embedding_dimensions 1536
  @chat_model "gpt-3.5-turbo"

  @impl true
  def chat_completion(messages, opts \\ %{}) do
    model = Map.get(opts, :model, @chat_model)
    max_tokens = Map.get(opts, :max_tokens, 500)
    temperature = Map.get(opts, :temperature, 0.7)

    case openai_client().chat_completion(%{
      model: model,
      messages: messages,
      max_tokens: max_tokens,
      temperature: temperature
    }) do
      {:ok, %{choices: [%{message: %{content: content}} | _]}} ->
        {:ok, String.trim(content)}
        
      {:error, reason} ->
        Logger.error("OpenAI chat completion failed: #{inspect(reason)}")
        {:error, "Failed to generate response"}
    end
  end

  @impl true
  def generate_embedding(text) do
    case openai_client().embeddings(%{
      model: @embedding_model,
      input: text
    }) do
      {:ok, %{data: [%{embedding: vector} | _]}} ->
        {:ok, vector}
        
      {:error, reason} ->
        Logger.error("OpenAI embedding request failed: #{inspect(reason)}")
        {:error, "Failed to generate embedding"}
    end
  end

  @impl true
  def get_embedding_model, do: @embedding_model

  @impl true
  def get_embedding_dimensions, do: @embedding_dimensions

  defp openai_client do
    case Application.get_env(:study_bot, :openai_api_key) do
      nil -> 
        Logger.warning("OpenAI API key not configured")
        OpenAI
      _api_key -> 
        # Use default OpenAI client with API key from environment
        OpenAI
    end
  end
end