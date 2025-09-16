defmodule StudyBot.Chat.ChatSession do
  use Ecto.Schema
  import Ecto.Changeset
  require Logger

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "chat_sessions" do
    field :title, :string
    field :messages, :string
    field :active, :boolean, default: true

    belongs_to :course, StudyBot.Courses.Course

    timestamps(type: :utc_datetime)
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [:course_id, :title, :messages, :active])
    |> validate_required([:course_id])
    |> validate_length(:title, max: 255)
    |> put_default_messages()
    |> assoc_constraint(:course)
  end

  defp put_default_messages(changeset) do
    case get_field(changeset, :messages) do
      nil -> put_change(changeset, :messages, "[]")
      _ -> changeset
    end
  end

  def add_message_changeset(session, message) do
    current_messages =
      session.messages
      |> decode_messages()
      |> Enum.map(&sanitize_message/1)

    updated_messages = current_messages ++ [sanitize_message(message)]

    change(session, %{
      messages: Jason.encode!(updated_messages),
      title: generate_title_if_needed(session.title, updated_messages)
    })
  end

  defp decode_messages(nil), do: []

  defp decode_messages(messages_json) do
    case Jason.decode(messages_json) do
      {:ok, messages} -> messages
      {:error, _} -> []
    end
  end

  defp generate_title_if_needed(nil, messages) when length(messages) >= 1 do
    case List.first(messages) do
      %{"role" => "user", "content" => content} ->
        content
        |> String.slice(0, 50)
        |> String.trim()
        |> case do
          "" -> "New Chat"
          title -> if String.length(title) == 50, do: title <> "...", else: title
        end

      _ ->
        "New Chat"
    end
  end

  defp generate_title_if_needed(existing_title, _), do: existing_title

  defp sanitize_message(%{"content" => content} = message) when is_binary(content) do
    sanitized = StudyBot.Text.sanitize(content)

    if sanitized != content do
      Logger.warning("Sanitized message content in ChatSession",
        original_hex: Base.encode16(content, case: :lower)
      )
    end

    Map.put(message, "content", sanitized)
  end

  defp sanitize_message(message), do: message
end
