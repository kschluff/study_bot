defmodule StudyBot.AI.OpenAIClient do
  @moduledoc """
  OpenAI API client implementation.
  """

  @behaviour StudyBot.AI.Client

  require Logger

  @embedding_dimensions 1536

  @impl true
  def chat_completion(messages, opts \\ %{}) do
    default_model = Application.get_env(:study_bot, :openai_chat_model, "gpt-4")
    model = Map.get(opts, :model, default_model)
    # GPT-5 models use reasoning tokens, so need more total tokens
    default_tokens = if String.starts_with?(model, "gpt-5"), do: 5000, else: 500
    max_tokens = Map.get(opts, :max_tokens, default_tokens)
    temperature = Map.get(opts, :temperature, 0.7)

    # Use max_completion_tokens for GPT-5 models, max_tokens for others
    token_param =
      if String.starts_with?(model, "gpt-5") do
        [max_completion_tokens: max_tokens]
      else
        [max_tokens: max_tokens]
      end

    # GPT-5 models only support temperature=1 (default), omit temperature param
    temperature_param =
      if String.starts_with?(model, "gpt-5") do
        []
      else
        [temperature: temperature]
      end

    params =
      [
        model: model,
        messages: messages
      ] ++ token_param ++ temperature_param

    api_key = Application.get_env(:study_bot, :openai_api_key)

    case OpenAI.chat_completion(params, %{
           api_key: api_key,
           organization_key: nil,
           beta: nil,
           http_options: [recv_timeout: 120_000]
         }) do
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
                {:error,
                 "Empty response content - model may have hit token limit or reasoning issue"}
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

    embedding_model =
      Application.get_env(:study_bot, :openai_embedding_model, "text-embedding-ada-002")

    case OpenAI.embeddings(
           [model: embedding_model, input: text],
           %{
             api_key: api_key,
             organization_key: nil,
             beta: nil,
             http_options: [recv_timeout: 60_000]
           }
         ) do
      {:ok, %{data: [%{"embedding" => vector} | _]}} ->
        {:ok, vector}

      {:error, reason} ->
        Logger.error("OpenAI embedding request failed: #{inspect(reason)}")
        {:error, "Failed to generate embedding"}
    end
  end

  @impl true
  def get_embedding_model,
    do: Application.get_env(:study_bot, :openai_embedding_model, "text-embedding-ada-002")

  @impl true
  def get_embedding_dimensions, do: @embedding_dimensions

  @impl true
  def text_to_speech(text, opts \\ %{}) do
    default_tts_model = Application.get_env(:study_bot, :openai_tts_model, "tts-1")
    model = Map.get(opts, :model, default_tts_model)
    voice = Map.get(opts, :voice, "alloy")
    response_format = Map.get(opts, :response_format, "mp3")
    speed = Map.get(opts, :speed, 1.0)

    api_key = Application.get_env(:study_bot, :openai_api_key)

    # Use Req to make the HTTP request since OpenAI Elixir SDK doesn't support TTS
    url = "https://api.openai.com/v1/audio/speech"

    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"}
    ]

    body =
      Jason.encode!(%{
        model: model,
        input: text,
        voice: voice,
        response_format: response_format,
        speed: speed
      })

    case Req.post(url, headers: headers, body: body) do
      {:ok, %{status: 200, body: audio_data}} ->
        {:ok, audio_data}

      {:ok, %{status: status, body: error_body}} ->
        Logger.error("OpenAI TTS request failed with status #{status}: #{inspect(error_body)}")
        {:error, "TTS request failed with status #{status}"}

      {:error, reason} ->
        Logger.error("OpenAI TTS request failed: #{inspect(reason)}")
        {:error, "Failed to generate speech"}
    end
  end
end
