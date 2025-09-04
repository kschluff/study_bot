defmodule StudyBot.Repo.Migrations.CreateChatSessions do
  use Ecto.Migration

  def change do
    create table(:chat_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :course_id, references(:courses, on_delete: :delete_all, type: :binary_id), null: false
      add :title, :string
      add :messages, :text
      add :active, :boolean, default: true

      timestamps(type: :utc_datetime)
    end

    create index(:chat_sessions, [:course_id])
    create index(:chat_sessions, [:active])
    create index(:chat_sessions, [:inserted_at])
  end
end
