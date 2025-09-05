defmodule StudyBot.Chat do
  @moduledoc """
  The Chat context manages chat sessions and message handling.
  """

  import Ecto.Query, warn: false
  alias StudyBot.Repo
  alias StudyBot.Chat.ChatSession

  def list_sessions(course_id) do
    from(s in ChatSession,
      where: s.course_id == ^course_id and s.active == true,
      order_by: [desc: s.updated_at]
    )
    |> Repo.all()
  end

  def get_session!(id), do: Repo.get!(ChatSession, id)

  def get_session(id), do: Repo.get(ChatSession, id)

  def create_session(attrs \\ %{}) do
    %ChatSession{}
    |> ChatSession.changeset(attrs)
    |> Repo.insert()
  end

  def add_message(%ChatSession{} = session, message) do
    session
    |> ChatSession.add_message_changeset(message)
    |> Repo.update()
  end

  def get_messages(%ChatSession{messages: nil}), do: []

  def get_messages(%ChatSession{messages: messages_json}) do
    case Jason.decode(messages_json) do
      {:ok, messages} -> messages
      {:error, _} -> []
    end
  end

  def delete_session(%ChatSession{} = session) do
    Repo.delete(session)
  end

  def deactivate_session(%ChatSession{} = session) do
    session
    |> ChatSession.changeset(%{active: false})
    |> Repo.update()
  end
end
