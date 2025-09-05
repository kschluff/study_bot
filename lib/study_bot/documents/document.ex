defmodule StudyBot.Documents.Document do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder,
           only: [
             :id,
             :filename,
             :original_filename,
             :file_type,
             :file_size,
             :status,
             :processed_at,
             :inserted_at,
             :updated_at
           ]}
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "documents" do
    field :filename, :string
    field :original_filename, :string
    field :file_type, :string
    field :file_size, :integer
    field :content, :string
    field :status, :string, default: "pending"
    field :error_message, :string
    field :processed_at, :utc_datetime

    belongs_to :course, StudyBot.Courses.Course
    has_many :document_chunks, StudyBot.Documents.DocumentChunk

    timestamps(type: :utc_datetime)
  end

  def changeset(document, attrs) do
    document
    |> cast(attrs, [
      :course_id,
      :filename,
      :original_filename,
      :file_type,
      :file_size,
      :content,
      :status,
      :error_message,
      :processed_at
    ])
    |> validate_required([:course_id, :filename, :original_filename, :file_type, :file_size])
    |> validate_inclusion(:status, ["pending", "processing", "processed", "failed"])
    |> validate_inclusion(:file_type, ["text", "pdf"])
    |> validate_number(:file_size, greater_than: 0)
    |> assoc_constraint(:course)
  end

  def processing_changeset(document) do
    change(document, %{
      status: "processing",
      error_message: nil,
      processed_at: nil
    })
  end

  def processed_changeset(document, content) do
    change(document, %{
      status: "processed",
      content: content,
      processed_at: DateTime.utc_now() |> DateTime.truncate(:second),
      error_message: nil
    })
  end

  def failed_changeset(document, error_message) do
    change(document, %{
      status: "failed",
      error_message: error_message,
      processed_at: nil
    })
  end
end
