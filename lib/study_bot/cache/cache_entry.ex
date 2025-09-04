defmodule StudyBot.Cache.CacheEntry do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "cache_entries" do
    field :query_hash, :string
    field :query_text, :string
    field :query_embedding, :string
    field :response_content, :string
    field :context_chunks, :string
    field :hit_count, :integer, default: 1
    field :last_accessed_at, :utc_datetime

    belongs_to :course, StudyBot.Courses.Course

    timestamps(type: :utc_datetime)
  end

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:course_id, :query_hash, :query_text, :query_embedding,
                    :response_content, :context_chunks, :hit_count, :last_accessed_at])
    |> validate_required([:course_id, :query_hash, :query_text, :query_embedding,
                          :response_content, :last_accessed_at])
    |> unique_constraint([:course_id, :query_hash])
    |> assoc_constraint(:course)
  end

  def access_changeset(entry) do
    change(entry, %{
      hit_count: entry.hit_count + 1,
      last_accessed_at: DateTime.utc_now()
    })
  end
end