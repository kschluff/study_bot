defmodule StudyBot.Courses.Course do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "courses" do
    field :name, :string
    field :description, :string
    field :color, :string, default: "#3B82F6"
    field :active, :boolean, default: true

    has_many :documents, StudyBot.Documents.Document
    has_many :document_chunks, StudyBot.Documents.DocumentChunk
    has_many :chat_sessions, StudyBot.Chat.ChatSession

    timestamps(type: :utc_datetime)
  end

  def changeset(course, attrs) do
    course
    |> cast(attrs, [:name, :description, :color, :active])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 255)
    |> validate_length(:description, max: 1000)
    |> validate_format(:color, ~r/^#[0-9A-Fa-f]{6}$/,
      message: "must be a valid hex color (e.g., #3B82F6)"
    )
    |> unique_constraint(:name)
  end
end
