defmodule StudyBot.Repo.Migrations.CreateCourses do
  use Ecto.Migration

  def change do
    create table(:courses, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :color, :string, default: "#3B82F6"
      add :active, :boolean, default: true

      timestamps(type: :utc_datetime)
    end

    create unique_index(:courses, [:name])
    create index(:courses, [:active])
  end
end
