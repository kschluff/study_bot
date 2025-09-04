defmodule StudyBot.Documents.DocumentChunk do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "document_chunks" do
    field :chunk_index, :integer
    field :content, :string
    field :token_count, :integer
    field :start_char, :integer
    field :end_char, :integer

    belongs_to :document, StudyBot.Documents.Document
    belongs_to :course, StudyBot.Courses.Course
    has_one :embedding, StudyBot.Embeddings.Embedding

    timestamps(type: :utc_datetime)
  end

  def changeset(chunk, attrs) do
    chunk
    |> cast(attrs, [:document_id, :course_id, :chunk_index, :content, 
                    :token_count, :start_char, :end_char])
    |> validate_required([:document_id, :course_id, :chunk_index, :content])
    |> validate_number(:chunk_index, greater_than_or_equal_to: 0)
    |> validate_length(:content, min: 1)
    |> unique_constraint([:document_id, :chunk_index])
    |> assoc_constraint(:document)
    |> assoc_constraint(:course)
  end
end