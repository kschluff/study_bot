defmodule StudyBot.Embeddings do
  @moduledoc """
  The Embeddings context manages vector embeddings for document chunks.
  """

  import Ecto.Query, warn: false
  alias StudyBot.Repo
  alias StudyBot.Embeddings.Embedding
  alias StudyBot.Documents.DocumentChunk
  alias StudyBot.AI.Client

  require Logger

  def create_embedding(attrs \\ %{}) do
    %Embedding{}
    |> Embedding.changeset(attrs)
    |> Repo.insert()
  end

  def get_embeddings_for_course(course_id) do
    from(e in Embedding,
         join: c in DocumentChunk, on: e.document_chunk_id == c.id,
         where: e.course_id == ^course_id,
         select: {e, c},
         order_by: [asc: c.chunk_index])
    |> Repo.all()
  end

  def generate_embeddings_for_document(document_id) do
    chunks = StudyBot.Documents.list_chunks(document_id)
    
    for chunk <- chunks do
      case generate_embedding_for_chunk(chunk) do
        {:ok, _embedding} -> 
          Logger.info("Generated embedding for chunk #{chunk.id}")
          
        {:error, reason} ->
          Logger.error("Failed to generate embedding for chunk #{chunk.id}: #{reason}")
      end
    end
  end

  def generate_embedding_for_chunk(%DocumentChunk{} = chunk) do
    with {:ok, vector} <- Client.generate_embedding(chunk.content) do
      create_embedding(%{
        document_chunk_id: chunk.id,
        course_id: chunk.course_id,
        embedding_vector: Jason.encode!(vector),
        model: Client.get_embedding_model(),
        dimensions: Client.get_embedding_dimensions()
      })
    end
  end

  def generate_query_embedding(query_text) do
    Client.generate_embedding(query_text)
  end

  def search_similar_chunks(course_id, query_vector, limit \\ 10) do
    embeddings = get_embeddings_for_course(course_id)
    
    embeddings
    |> Enum.map(fn {embedding, chunk} ->
      stored_vector = Jason.decode!(embedding.embedding_vector)
      similarity = cosine_similarity(query_vector, stored_vector)
      {chunk, similarity}
    end)
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.take(limit)
    |> Enum.map(&elem(&1, 0))
  end

  defp cosine_similarity(vec1, vec2) when length(vec1) == length(vec2) do
    dot_product = Enum.zip(vec1, vec2)
                 |> Enum.map(fn {a, b} -> a * b end)
                 |> Enum.sum()
    
    magnitude1 = :math.sqrt(Enum.map(vec1, &(&1 * &1)) |> Enum.sum())
    magnitude2 = :math.sqrt(Enum.map(vec2, &(&1 * &1)) |> Enum.sum())
    
    if magnitude1 == 0 or magnitude2 == 0 do
      0.0
    else
      dot_product / (magnitude1 * magnitude2)
    end
  end

  defp cosine_similarity(_, _), do: 0.0
end