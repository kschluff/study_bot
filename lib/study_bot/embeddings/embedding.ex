defmodule StudyBot.Embeddings.Embedding do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "embeddings" do
    field :embedding_vector, :string
    field :model, :string
    field :dimensions, :integer

    belongs_to :document_chunk, StudyBot.Documents.DocumentChunk
    belongs_to :course, StudyBot.Courses.Course

    timestamps(type: :utc_datetime)
  end

  def changeset(embedding, attrs) do
    embedding
    |> cast(attrs, [:document_chunk_id, :course_id, :embedding_vector, :model, :dimensions])
    |> validate_required([:document_chunk_id, :course_id, :embedding_vector, :model, :dimensions])
    |> validate_number(:dimensions, greater_than: 0)
    |> assoc_constraint(:document_chunk)
    |> assoc_constraint(:course)
  end
end