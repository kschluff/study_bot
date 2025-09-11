defmodule StudyBot.Documents do
  @moduledoc """
  The Documents context manages document upload, processing, and chunking operations.
  """

  import Ecto.Query, warn: false
  alias StudyBot.Repo
  alias StudyBot.Documents.{Document, DocumentChunk}
  alias StudyBot.{VectorStore, AI.Client}

  require Logger

  # Document operations

  def list_documents(course_id) do
    from(d in Document,
      where: d.course_id == ^course_id,
      order_by: [desc: d.inserted_at]
    )
    |> Repo.all()
  end

  def get_document!(id), do: Repo.get!(Document, id)

  def get_document(id), do: Repo.get(Document, id)

  def create_document(attrs \\ %{}) do
    %Document{}
    |> Document.changeset(attrs)
    |> Repo.insert()
  end

  def update_document(%Document{} = document, attrs) do
    document
    |> Document.changeset(attrs)
    |> Repo.update()
  end

  def mark_processing(%Document{} = document) do
    case document
         |> Document.processing_changeset()
         |> Repo.update() do
      {:ok, updated_document} = result ->
        broadcast_document_update(updated_document)
        result

      error ->
        error
    end
  end

  def mark_processed(%Document{} = document, content) do
    case document
         |> Document.processed_changeset(content)
         |> Repo.update() do
      {:ok, updated_document} = result ->
        broadcast_document_update(updated_document)
        result

      error ->
        error
    end
  end

  def mark_failed(%Document{} = document, error_message) do
    case document
         |> Document.failed_changeset(error_message)
         |> Repo.update() do
      {:ok, updated_document} = result ->
        broadcast_document_update(updated_document)
        result

      error ->
        error
    end
  end

  def delete_document(%Document{} = document) do
    # Delete from vector store first
    VectorStore.delete_document(document.course_id, document.id)
    # Then delete from SQLite
    Repo.delete(document)
  end

  # Document chunk operations

  def list_chunks(document_id) do
    from(c in DocumentChunk,
      where: c.document_id == ^document_id,
      order_by: [asc: c.chunk_index]
    )
    |> Repo.all()
  end

  def create_chunk(attrs \\ %{}) do
    %DocumentChunk{}
    |> DocumentChunk.changeset(attrs)
    |> Repo.insert()
  end

  def create_chunks(chunks_data) when is_list(chunks_data) do
    chunks_data
    |> Enum.map(&DocumentChunk.changeset(%DocumentChunk{}, &1))
    |> Enum.map(&Repo.insert!/1)
  end

  def delete_chunks(document_id) do
    from(c in DocumentChunk, where: c.document_id == ^document_id)
    |> Repo.delete_all()
  end

  # Text processing utilities

  def chunk_text(text, chunk_size \\ 500, overlap \\ 50) do
    text
    |> String.trim()
    |> split_into_chunks(chunk_size, overlap)
    |> Enum.with_index()
    |> Enum.map(fn {content, index} ->
      start_char = calculate_start_char(text, content, index)
      end_char = start_char + String.length(content) - 1

      %{
        chunk_index: index,
        content: String.trim(content),
        token_count: estimate_tokens(content),
        start_char: start_char,
        end_char: end_char
      }
    end)
  end

  defp split_into_chunks(text, chunk_size, overlap) do
    words = String.split(text, ~r/\s+/)
    create_overlapping_chunks(words, chunk_size, overlap)
  end

  defp create_overlapping_chunks(words, chunk_size, overlap) do
    create_overlapping_chunks(words, chunk_size, overlap, [])
  end

  defp create_overlapping_chunks([], _chunk_size, _overlap, acc) do
    Enum.reverse(acc)
  end

  defp create_overlapping_chunks(words, chunk_size, _overlap, acc)
       when length(words) <= chunk_size do
    chunk = Enum.join(words, " ")
    Enum.reverse([chunk | acc])
  end

  defp create_overlapping_chunks(words, chunk_size, overlap, acc) do
    {chunk_words, _remaining} = Enum.split(words, chunk_size)
    chunk = Enum.join(chunk_words, " ")

    next_start = max(0, chunk_size - overlap)
    {_skip, next_words} = Enum.split(words, next_start)

    create_overlapping_chunks(next_words, chunk_size, overlap, [chunk | acc])
  end

  defp calculate_start_char(full_text, chunk_content, index) do
    if index == 0 do
      0
    else
      case String.split(full_text, chunk_content, parts: 2) do
        [prefix, _] -> String.length(prefix)
        # fallback estimation
        _ -> index * 400
      end
    end
  end

  defp estimate_tokens(text) do
    # Rough estimation: ~4 characters per token
    div(String.length(text), 4)
  end

  # File processing

  def process_uploaded_file(file_path, course_id, original_filename) do
    file_size = File.stat!(file_path).size
    file_type = determine_file_type(original_filename)
    filename = generate_filename(original_filename)

    case create_document(%{
           course_id: course_id,
           filename: filename,
           original_filename: original_filename,
           file_type: file_type,
           file_size: file_size
         }) do
      {:ok, document} ->
        Task.start(fn -> process_document_async(document, file_path) end)
        {:ok, document}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp process_document_async(document, file_path) do
    case mark_processing(document) do
      {:ok, document} ->
        case extract_text_content(file_path, document.file_type) do
          {:ok, content} ->
            process_document_content(document, content)

          {:error, reason} ->
            mark_failed(document, "Failed to extract content: #{reason}")
        end

      {:error, _reason} ->
        mark_failed(document, "Failed to mark document as processing")
    end
  end

  defp process_document_content(document, content) do
    case mark_processed(document, content) do
      {:ok, updated_document} ->
        chunks = chunk_text(content)

        chunk_data =
          Enum.map(
            chunks,
            &Map.merge(&1, %{
              document_id: updated_document.id,
              course_id: updated_document.course_id
            })
          )

        # Create chunks in SQLite
        created_chunks = create_chunks(chunk_data)

        # Generate embeddings and store in Chroma
        process_chunks_for_vector_storage(updated_document, created_chunks)

      {:error, _reason} ->
        mark_failed(document, "Failed to save processed content")
    end
  end

  defp process_chunks_for_vector_storage(document, chunks) do
    # Ensure collection exists for this course (always succeeds now)
    {:ok, _collection_name} = VectorStore.create_collection(document.course_id)

    # Generate embeddings for all chunks
    chunks_with_embeddings = generate_embeddings_for_chunks(chunks)

    # Store in Chroma
    case VectorStore.add_documents(document.course_id, chunks_with_embeddings) do
      :ok ->
        Logger.info(
          "Successfully stored #{length(chunks)} chunks in vector database for document #{document.id}"
        )

      {:error, reason} ->
        Logger.error("Failed to store chunks in vector database: #{reason}")
        mark_failed(document, "Failed to store vectors: #{reason}")
    end
  end

  defp generate_embeddings_for_chunks(chunks) do
    chunks
    |> Enum.map(fn chunk ->
      case Client.generate_embedding(chunk.content) do
        {:ok, embedding} ->
          {chunk, embedding}

        {:error, reason} ->
          Logger.error("Failed to generate embedding for chunk #{chunk.id}: #{reason}")
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp extract_text_content(file_path, "text") do
    case File.read(file_path) do
      {:ok, content} -> {:ok, content}
      {:error, reason} -> {:error, reason}
    end
  end

  defp extract_text_content(file_path, "pdf") do
    case System.cmd("pdftotext", [file_path, "-"]) do
      {content, 0} -> {:ok, String.trim(content)}
      {error, _} -> {:error, "PDF extraction failed: #{error}"}
    end
  rescue
    _ -> {:error, "pdftotext command not found or failed. Please install poppler-utils"}
  end

  defp determine_file_type(filename) do
    case Path.extname(filename) |> String.downcase() do
      ".pdf" -> "pdf"
      _ -> "text"
    end
  end

  defp generate_filename(original_filename) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    extension = Path.extname(original_filename)
    base_name = Path.basename(original_filename, extension)
    "#{timestamp}_#{base_name}#{extension}"
  end

  # PubSub broadcast helper
  defp broadcast_document_update(%Document{} = document) do
    Phoenix.PubSub.broadcast(
      StudyBot.PubSub,
      "course:#{document.course_id}:documents",
      {:document_updated, document}
    )
  end
end
