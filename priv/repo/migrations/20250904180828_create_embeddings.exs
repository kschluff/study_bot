defmodule StudyBot.Repo.Migrations.CreateEmbeddings do
  use Ecto.Migration

  def change do
    create table(:embeddings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :document_chunk_id, references(:document_chunks, on_delete: :delete_all, type: :binary_id), null: false
      add :course_id, references(:courses, on_delete: :delete_all, type: :binary_id), null: false
      add :embedding_vector, :text, null: false
      add :model, :string, null: false
      add :dimensions, :integer, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:embeddings, [:document_chunk_id])
    create index(:embeddings, [:course_id])
    create index(:embeddings, [:model])
  end
end
