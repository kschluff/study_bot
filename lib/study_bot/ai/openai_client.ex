defmodule StudyBot.AI.OpenAIClient do
  @moduledoc """
  OpenAI API client implementation.
  """

  @behaviour StudyBot.AI.Client

  require Logger

  @embedding_model "text-embedding-ada-002"
  @embedding_dimensions 1536
#  @chat_model "gpt-3.5-turbo"
  @chat_model "gpt-5-mini"

  @impl true
  def chat_completion(messages, opts \\ %{}) do
    model = Map.get(opts, :model, @chat_model)
    # GPT-5 models use reasoning tokens, so need more total tokens
    default_tokens = if String.starts_with?(model, "gpt-5"), do: 2000, else: 500
    max_tokens = Map.get(opts, :max_tokens, default_tokens)
    temperature = Map.get(opts, :temperature, 0.7)

    # Use max_completion_tokens for GPT-5 models, max_tokens for others
    token_param = if String.starts_with?(model, "gpt-5") do
      [max_completion_tokens: max_tokens]
    else
      [max_tokens: max_tokens]
    end

    # GPT-5 models only support temperature=1 (default), omit temperature param
    temperature_param = if String.starts_with?(model, "gpt-5") do
      []
    else
      [temperature: temperature]
    end

    params = [
      model: model,
      messages: messages
    ] ++ token_param ++ temperature_param

    api_key = Application.get_env(:study_bot, :openai_api_key)

    case OpenAI.chat_completion(params, %{api_key: api_key, organization_key: nil, beta: nil, http_options: [recv_timeout: 120_000]}) do
      {:ok, response} ->
        Logger.debug("OpenAI response: #{inspect(response, pretty: true)}")
        case response do
          %{choices: [%{"message" => %{"content" => content}} | _]} when content != "" ->
            {:ok, String.trim(content)}
          %{choices: [%{"message" => message} | _]} ->
            # Handle reasoning models that might have empty content
            Logger.warning("Empty content in response, full message: #{inspect(message)}")
            case message do
              %{"refusal" => refusal} when refusal != nil ->
                {:error, "Request refused: #{refusal}"}
              _ ->
                {:error, "Empty response content - model may have hit token limit or reasoning issue"}
            end
          _ ->
            Logger.error("Unexpected response format: #{inspect(response)}")
            {:error, "Unexpected response format"}
        end

      {:error, reason} ->
        Logger.error("OpenAI chat completion failed: #{inspect(reason)}")
        {:error, "Failed to generate response"}
    end
  end

  @impl true
  def generate_embedding(text) do
    api_key = Application.get_env(:study_bot, :openai_api_key)

    case OpenAI.embeddings(
           [model: @embedding_model, input: text],
           %{api_key: api_key, organization_key: nil, beta: nil, http_options: [recv_timeout: 60_000]}
         ) do
      {:ok, %{data: [%{"embedding" => vector} | _]}} ->
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
end
