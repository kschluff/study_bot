defmodule StudyBot.VectorStore do
  @moduledoc """
  Interface for vector database operations using Chroma.
  """

  require Logger

  @tenant "default_tenant"
  @database "default_database"

  @doc """
  Creates a collection in Chroma for a specific course using the V2 API.
  """
  def create_collection(course_id) do
    collection_name = collection_name_for_course(course_id)

    # Ensure tenant and database exist first
    with :ok <- ensure_tenant_exists(),
         :ok <- ensure_database_exists() do
      case create_collection_v2(collection_name, course_id) do
        {:ok, _collection} -> {:ok, collection_name}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Adds document chunks with their embeddings to the collection.
  Processes in batches to avoid connection issues with large payloads.
  """
  def add_documents(course_id, chunks_with_embeddings) do
    collection_name = collection_name_for_course(course_id)

    Logger.info(
      "Adding #{length(chunks_with_embeddings)} documents to collection: #{collection_name}"
    )

    # Process in batches of 10 to avoid large payload issues
    batch_size = 10

    chunks_with_embeddings
    |> Enum.chunk_every(batch_size)
    |> Enum.with_index()
    |> Enum.reduce_while(:ok, fn {batch, batch_index}, _acc ->
      Logger.info(
        "Processing batch #{batch_index + 1}/#{ceil(length(chunks_with_embeddings) / batch_size)}"
      )

      case add_batch_to_collection(collection_name, course_id, batch) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp add_batch_to_collection(collection_name, _course_id, chunks_with_embeddings) do
    {ids, embeddings, metadatas, documents} =
      chunks_with_embeddings
      |> Enum.reduce({[], [], [], []}, fn {chunk, embedding},
                                          {ids, embeddings, metadatas, documents} ->
        chunk_id = "#{chunk.document_id}_#{chunk.chunk_index}"

        metadata = %{
          document_id: chunk.document_id,
          chunk_index: chunk.chunk_index,
          course_id: chunk.course_id,
          token_count: chunk.token_count,
          start_char: chunk.start_char,
          end_char: chunk.end_char
        }

        {
          [chunk_id | ids],
          [embedding | embeddings],
          [metadata | metadatas],
          [chunk.content | documents]
        }
      end)

    # Get collection ID first
    case get_collection_id(collection_name) do
      {:ok, collection_id} ->
        add_documents_to_collection_v2(collection_id, ids, embeddings, metadatas, documents)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp add_documents_to_collection_v2(collection_id, ids, embeddings, metadatas, documents) do
    url =
      "#{chroma_base_url()}/api/v2/tenants/#{@tenant}/databases/#{@database}/collections/#{collection_id}/add"

    payload = %{
      ids: Enum.reverse(ids),
      embeddings: Enum.reverse(embeddings),
      metadatas: Enum.reverse(metadatas),
      documents: Enum.reverse(documents)
    }

    case Req.post(url, json: payload, connect_options: [timeout: 30_000], receive_timeout: 60_000) do
      {:ok, %{status: status}} when status in 200..299 ->
        Logger.debug("Successfully added batch to Chroma collection")
        :ok

      {:ok, response} ->
        Logger.error("HTTP error from Chroma: #{inspect(response)}")
        {:error, "Failed to add documents"}

      {:error, reason} ->
        Logger.error("Chroma request failed: #{inspect(reason)}")
        {:error, "Connection to vector database failed"}
    end
  end

  defp ensure_tenant_exists do
    url = "#{chroma_base_url()}/api/v2/tenants"

    case Req.post(url, json: %{name: @tenant}) do
      {:ok, %{status: status}} when status in 200..299 ->
        :ok

      {:ok, %{status: 409}} ->
        # Tenant already exists
        :ok

      {:ok, response} ->
        Logger.error("Failed to create tenant: #{inspect(response)}")
        {:error, "Failed to create tenant"}

      {:error, reason} ->
        Logger.error("Request failed: #{inspect(reason)}")
        {:error, "Connection failed"}
    end
  end

  defp ensure_database_exists do
    url = "#{chroma_base_url()}/api/v2/tenants/#{@tenant}/databases"

    case Req.post(url, json: %{name: @database}) do
      {:ok, %{status: status}} when status in 200..299 ->
        :ok

      {:ok, %{status: 409}} ->
        # Database already exists
        :ok

      {:ok, response} ->
        Logger.error("Failed to create database: #{inspect(response)}")
        {:error, "Failed to create database"}

      {:error, reason} ->
        Logger.error("Request failed: #{inspect(reason)}")
        {:error, "Connection failed"}
    end
  end

  defp create_collection_v2(collection_name, course_id) do
    url = "#{chroma_base_url()}/api/v2/tenants/#{@tenant}/databases/#{@database}/collections"

    case Req.post(url,
           json: %{
             name: collection_name,
             metadata: %{course_id: course_id},
             get_or_create: true
           }
         ) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, response} ->
        Logger.error("Failed to create collection: #{inspect(response)}")
        {:error, "Failed to create collection"}

      {:error, reason} ->
        Logger.error("Request failed: #{inspect(reason)}")
        {:error, "Connection failed"}
    end
  end

  defp get_collection_id(collection_name) do
    url = "#{chroma_base_url()}/api/v2/tenants/#{@tenant}/databases/#{@database}/collections"

    case Req.get(url) do
      {:ok, %{status: status, body: collections}} when status in 200..299 ->
        case Enum.find(collections, fn col -> col["name"] == collection_name end) do
          %{"id" => collection_id} -> {:ok, collection_id}
          nil -> {:error, "Collection not found"}
        end

      {:ok, response} ->
        Logger.error("Failed to list collections: #{inspect(response)}")
        {:error, "Failed to list collections"}

      {:error, reason} ->
        Logger.error("Request failed: #{inspect(reason)}")
        {:error, "Connection failed"}
    end
  end

  @doc """
  Performs similarity search in the collection using V2 API.
  """
  def similarity_search(course_id, query_embedding, limit \\ 5) do
    collection_name = collection_name_for_course(course_id)

    case get_collection_id(collection_name) do
      {:ok, collection_id} ->
        url =
          "#{chroma_base_url()}/api/v2/tenants/#{@tenant}/databases/#{@database}/collections/#{collection_id}/query"

        case Req.post(url,
               json: %{
                 query_embeddings: [query_embedding],
                 n_results: limit,
                 include: ["documents", "metadatas", "distances"]
               }
             ) do
          {:ok, %{status: status, body: body}} when status in 200..299 ->
            results = parse_search_results(body)
            {:ok, results}

          {:ok, response} ->
            Logger.error("Failed to search Chroma: #{inspect(response)}")
            {:error, "Search failed"}

          {:error, reason} ->
            Logger.error("Chroma request failed: #{inspect(reason)}")
            {:error, "Connection to vector database failed"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Deletes all documents for a specific document from the collection using V2 API.
  """
  def delete_document(course_id, document_id) do
    collection_name = collection_name_for_course(course_id)

    case get_collection_id(collection_name) do
      {:ok, collection_id} ->
        url =
          "#{chroma_base_url()}/api/v2/tenants/#{@tenant}/databases/#{@database}/collections/#{collection_id}/delete"

        case Req.post(url,
               json: %{
                 where: %{document_id: document_id}
               }
             ) do
          {:ok, %{status: status}} when status in 200..299 ->
            :ok

          {:ok, response} ->
            Logger.error("Failed to delete document from Chroma: #{inspect(response)}")
            {:error, "Failed to delete document"}

          {:error, reason} ->
            Logger.error("Chroma request failed: #{inspect(reason)}")
            {:error, "Connection to vector database failed"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Deletes a collection (when a course is deleted) using V2 API.
  """
  def delete_collection(course_id) do
    collection_name = collection_name_for_course(course_id)

    case get_collection_id(collection_name) do
      {:ok, collection_id} ->
        url =
          "#{chroma_base_url()}/api/v2/tenants/#{@tenant}/databases/#{@database}/collections/#{collection_id}"

        case Req.delete(url) do
          {:ok, %{status: status}} when status in 200..299 ->
            :ok

          {:ok, response} ->
            Logger.error("Failed to delete Chroma collection: #{inspect(response)}")
            {:error, "Failed to delete collection"}

          {:error, reason} ->
            Logger.error("Chroma request failed: #{inspect(reason)}")
            {:error, "Connection to vector database failed"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp chroma_base_url do
    :study_bot
    |> Application.get_env(:chroma, [])
    |> Keyword.get(:base_url, "http://localhost:8000")
  end

  defp collection_name_for_course(course_id) do
    # Replace any problematic characters in UUID for Chroma collection names
    safe_id = String.replace(course_id, "-", "_")
    collection_name = "course_#{safe_id}"
    Logger.debug("Collection name for course #{course_id}: #{collection_name}")
    collection_name
  end

  defp parse_search_results(%{
         "documents" => [documents],
         "metadatas" => [metadatas],
         "distances" => [distances]
       }) do
    documents
    |> Enum.zip(metadatas)
    |> Enum.zip(distances)
    |> Enum.map(fn {{document, metadata}, distance} ->
      %{
        content: document,
        metadata: metadata,
        distance: distance
      }
    end)
  end

  defp parse_search_results(body) do
    Logger.warning("Unexpected Chroma response format: #{inspect(body)}")
    []
  end
end
