defmodule StudyBot.Repo.Migrations.CreateDocuments do
  use Ecto.Migration

  def change do
    create table(:documents, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :course_id, references(:courses, on_delete: :delete_all, type: :binary_id), null: false
      add :filename, :string, null: false
      add :original_filename, :string, null: false
      add :file_type, :string, null: false
      add :file_size, :integer, null: false
      add :content, :text
      add :status, :string, null: false, default: "pending"
      add :error_message, :text
      add :processed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:documents, [:course_id])
    create index(:documents, [:status])
    create index(:documents, [:filename])
  end
end
