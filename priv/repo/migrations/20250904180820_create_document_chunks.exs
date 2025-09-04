defmodule StudyBot.Repo.Migrations.CreateDocumentChunks do
  use Ecto.Migration

  def change do
    create table(:document_chunks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :document_id, references(:documents, on_delete: :delete_all, type: :binary_id), null: false
      add :course_id, references(:courses, on_delete: :delete_all, type: :binary_id), null: false
      add :chunk_index, :integer, null: false
      add :content, :text, null: false
      add :token_count, :integer
      add :start_char, :integer
      add :end_char, :integer

      timestamps(type: :utc_datetime)
    end

    create index(:document_chunks, [:document_id])
    create index(:document_chunks, [:course_id])
    create index(:document_chunks, [:chunk_index])
    create unique_index(:document_chunks, [:document_id, :chunk_index])
  end
end
