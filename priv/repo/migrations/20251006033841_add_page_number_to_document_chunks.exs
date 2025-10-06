defmodule StudyBot.Repo.Migrations.AddPageNumberToDocumentChunks do
  use Ecto.Migration

  def change do
    alter table(:document_chunks) do
      add :page_number, :integer
    end
  end
end
