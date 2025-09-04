defmodule StudyBot.AI.AnthropicClient do
  @moduledoc """
  Anthropic Claude API client implementation.
  Uses OpenAI for embeddings since Anthropic doesn't provide embedding models.
  """

  @behaviour StudyBot.AI.Client

  require Logger

  # For embeddings, we still use OpenAI since Anthropic doesn't provide embeddings
  @embedding_model "text-embedding-ada-002"
  @embedding_dimensions 1536
  @chat_model "claude-3-haiku-20240307"

  @impl true
  def chat_completion(messages, opts \\ %{}) do
    model = Map.get(opts, :model, @chat_model)
    max_tokens = Map.get(opts, :max_tokens, 500)
    temperature = Map.get(opts, :temperature, 0.7)

    # Convert OpenAI-style messages to Anthropic format
    {system_message, claude_messages} = convert_messages_to_claude_format(messages)

    request_body = %{
      model: model,
      max_tokens: max_tokens,
      temperature: temperature,
      messages: claude_messages
    }
    |> maybe_add_system_message(system_message)

    case make_anthropic_request("/v1/messages", request_body) do
      {:ok, %{"content" => [%{"text" => text} | _]}} ->
        {:ok, String.trim(text)}
        
      {:ok, %{"error" => %{"message" => error_msg}}} ->
        Logger.error("Anthropic API error: #{error_msg}")
        {:error, "Failed to generate response: #{error_msg}"}
        
      {:error, reason} ->
        Logger.error("Anthropic chat completion failed: #{inspect(reason)}")
        {:error, "Failed to generate response"}
    end
  end

  @impl true
  def generate_embedding(text) do
    # Use OpenAI for embeddings since Anthropic doesn't provide embedding models
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

  defp convert_messages_to_claude_format(messages) do
    system_messages = Enum.filter(messages, &(&1.role == "system"))
    non_system_messages = Enum.reject(messages, &(&1.role == "system"))

    system_content = 
      system_messages
      |> Enum.map(& &1.content)
      |> Enum.join("\n\n")
      |> case do
        "" -> nil
        content -> content
      end

    claude_messages = 
      non_system_messages
      |> Enum.map(fn message ->
        %{
          role: convert_role(message.role),
          content: message.content
        }
      end)

    {system_content, claude_messages}
  end

  defp convert_role("user"), do: "user"
  defp convert_role("assistant"), do: "assistant"
  defp convert_role(_), do: "user"  # Default fallback

  defp maybe_add_system_message(request_body, nil), do: request_body
  defp maybe_add_system_message(request_body, system_message) do
    Map.put(request_body, :system, system_message)
  end

  defp make_anthropic_request(endpoint, body) do
    api_key = Application.get_env(:study_bot, :anthropic_api_key)
    
    if api_key do
      headers = [
        {"Authorization", "Bearer #{api_key}"},
        {"Content-Type", "application/json"},
        {"anthropic-version", "2023-06-01"}
      ]

      url = "https://api.anthropic.com" <> endpoint

      case Req.post(url, json: body, headers: headers) do
        {:ok, %{status: 200, body: response_body}} ->
          {:ok, response_body}
          
        {:ok, %{status: status, body: error_body}} ->
          Logger.error("Anthropic API returned status #{status}: #{inspect(error_body)}")
          {:error, "API request failed with status #{status}"}
          
        {:error, reason} ->
          Logger.error("Anthropic API request failed: #{inspect(reason)}")
          {:error, reason}
      end
    else
      Logger.error("Anthropic API key not configured")
      {:error, "API key not configured"}
    end
  end

  defp openai_client do
    # Used only for embeddings
    case Application.get_env(:study_bot, :openai_api_key) do
      nil -> 
        Logger.warning("OpenAI API key not configured (needed for embeddings)")
        OpenAI
      _api_key -> 
        # Use default OpenAI client with API key from environment
        OpenAI
    end
  end
end