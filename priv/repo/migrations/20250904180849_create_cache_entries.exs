defmodule StudyBot.Repo.Migrations.CreateCacheEntries do
  use Ecto.Migration

  def change do
    create table(:cache_entries, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :course_id, references(:courses, on_delete: :delete_all, type: :binary_id), null: false
      add :query_hash, :string, null: false
      add :query_text, :text, null: false
      add :query_embedding, :text, null: false
      add :response_content, :text, null: false
      add :context_chunks, :text
      add :hit_count, :integer, default: 1
      add :last_accessed_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:cache_entries, [:course_id])
    create index(:cache_entries, [:query_hash])
    create index(:cache_entries, [:last_accessed_at])
    create unique_index(:cache_entries, [:course_id, :query_hash])
  end
end
