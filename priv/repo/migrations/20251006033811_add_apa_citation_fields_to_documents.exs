defmodule StudyBot.Repo.Migrations.AddApaCitationFieldsToDocuments do
  use Ecto.Migration

  def change do
    alter table(:documents) do
      add :author, :text
      add :title, :text
      add :publication_year, :integer
      add :publisher, :text
    end
  end
end
