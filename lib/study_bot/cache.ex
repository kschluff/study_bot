defmodule StudyBot.Cache do
  @moduledoc """
  The Cache context manages semantic LRU caching for query results.
  """

  import Ecto.Query, warn: false
  alias StudyBot.Repo
  alias StudyBot.Cache.CacheEntry

  require Logger

  @cache_ttl_hours 24
  @max_cache_entries_per_course 100
  # Increased from 0.85 to require much higher similarity
  @similarity_threshold 0.99

  def lookup_cache(course_id, query_text, query_embedding) do
    query_hash = generate_query_hash(query_text)
    Logger.info("Cache lookup for query: '#{query_text}' (hash: #{query_hash})")

    # First try exact hash match
    case get_by_hash(course_id, query_hash) do
      %CacheEntry{} = entry ->
        Logger.info("Cache hit: exact hash match for '#{query_text}'")
        update_access(entry)
        {:hit, entry.response_content}

      nil ->
        Logger.info("Cache miss: no exact hash match, trying semantic similarity")
        # Try semantic similarity search
        search_similar_cached_queries(course_id, query_embedding)
    end
  end

  def cache_response(
        course_id,
        query_text,
        query_embedding,
        response_content,
        context_chunks \\ nil
      ) do
    query_hash = generate_query_hash(query_text)

    attrs = %{
      course_id: course_id,
      query_hash: query_hash,
      query_text: query_text,
      query_embedding: Jason.encode!(query_embedding),
      response_content: response_content,
      context_chunks: if(context_chunks, do: Jason.encode!(context_chunks)),
      last_accessed_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    case create_cache_entry(attrs) do
      {:ok, entry} ->
        cleanup_old_entries(course_id)
        {:ok, entry}

      {:error, changeset} ->
        Logger.warning("Failed to cache response: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end

  def invalidate_course_cache(course_id) do
    from(c in CacheEntry, where: c.course_id == ^course_id)
    |> Repo.delete_all()
  end

  def cleanup_expired_cache do
    cutoff = DateTime.utc_now() |> DateTime.add(-@cache_ttl_hours, :hour)

    from(c in CacheEntry, where: c.last_accessed_at < ^cutoff)
    |> Repo.delete_all()
  end

  defp get_by_hash(course_id, query_hash) do
    from(c in CacheEntry,
      where: c.course_id == ^course_id and c.query_hash == ^query_hash
    )
    |> Repo.one()
  end

  defp search_similar_cached_queries(course_id, query_embedding) do
    entries =
      from(c in CacheEntry,
        where: c.course_id == ^course_id,
        order_by: [desc: c.last_accessed_at],
        limit: 50
      )
      |> Repo.all()

    Logger.info("Found #{length(entries)} cached entries for semantic similarity search")

    case find_most_similar_entry(entries, query_embedding) do
      {%CacheEntry{} = entry, similarity} when similarity >= @similarity_threshold ->
        Logger.info(
          "Semantic cache hit: similarity #{similarity} (threshold: #{@similarity_threshold}) for query '#{entry.query_text}'"
        )

        update_access(entry)
        {:hit, entry.response_content}

      {%CacheEntry{} = entry, similarity} ->
        Logger.info(
          "Semantic cache miss: best similarity #{similarity} (threshold: #{@similarity_threshold}) for query '#{entry.query_text}'"
        )

        :miss

      _ ->
        Logger.info("Semantic cache miss: no similar entries found")
        :miss
    end
  end

  defp find_most_similar_entry(entries, query_embedding) do
    entries
    |> Enum.map(fn entry ->
      stored_embedding = Jason.decode!(entry.query_embedding)
      similarity = cosine_similarity(query_embedding, stored_embedding)
      {entry, similarity}
    end)
    |> Enum.max_by(&elem(&1, 1), fn -> {nil, 0.0} end)
  end

  defp cosine_similarity(vec1, vec2) when length(vec1) == length(vec2) do
    dot_product =
      Enum.zip(vec1, vec2)
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

  defp create_cache_entry(attrs) do
    %CacheEntry{}
    |> CacheEntry.changeset(attrs)
    |> Repo.insert()
  end

  defp update_access(%CacheEntry{} = entry) do
    entry
    |> CacheEntry.access_changeset()
    |> Repo.update()
  end

  defp cleanup_old_entries(course_id) do
    # Keep only the most recent entries per course, based on LRU
    entries_to_keep =
      from(c in CacheEntry,
        where: c.course_id == ^course_id,
        order_by: [desc: c.last_accessed_at],
        limit: @max_cache_entries_per_course,
        select: c.id
      )
      |> Repo.all()

    if length(entries_to_keep) >= @max_cache_entries_per_course do
      from(c in CacheEntry,
        where: c.course_id == ^course_id and c.id not in ^entries_to_keep
      )
      |> Repo.delete_all()
    end
  end

  defp generate_query_hash(query_text) do
    :crypto.hash(:md5, String.downcase(String.trim(query_text)))
    |> Base.encode16(case: :lower)
  end

  # Scheduled cleanup task
  def start_cleanup_scheduler do
    # Run cleanup every hour
    :timer.apply_interval(60 * 60 * 1000, __MODULE__, :cleanup_expired_cache, [])
  end
end
