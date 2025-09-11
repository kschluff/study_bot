defmodule StudyBot.RAG do
  @moduledoc """
  The RAG (Retrieval-Augmented Generation) system that combines document search
  and response generation.
  """

  alias StudyBot.{Courses, Documents, VectorStore, Chat}
  alias StudyBot.Documents.DocumentChunk
  alias StudyBot.AI.Client

  require Logger

  @max_context_chunks 5

  def process_query(course_id, query_text, session_id \\ nil) do
    with {:ok, course} <- get_course(course_id),
         {:ok, query_embedding} <- Client.generate_embedding(query_text) do
      # Get conversation context from session
      conversation_context = get_conversation_context(session_id)

      Logger.info("Processing query for course #{course.name}")

      process_query_with_retrieval(
        course,
        query_text,
        query_embedding,
        session_id,
        conversation_context
      )
    else
      error -> error
    end
  end

  defp process_query_with_retrieval(
         course,
         query_text,
         query_embedding,
         session_id,
         conversation_context
       ) do
    # Perform hybrid search
    relevant_chunks = search_relevant_content(course.id, query_text, query_embedding)

    case relevant_chunks do
      [] ->
        # No relevant content found, use fallback LLM
        response = generate_fallback_response(query_text, course.name, conversation_context)
        maybe_save_to_session(session_id, query_text, response)
        {:ok, response, :fallback}

      chunks when chunks != [] ->
        # Generate RAG response with context
        case generate_rag_response(query_text, chunks, course.name, conversation_context) do
          {:ok, response} ->
            maybe_save_to_session(session_id, query_text, response)
            {:ok, response, :rag}

          {:error, reason} ->
            Logger.error("Failed to generate RAG response: #{reason}")
            response = generate_fallback_response(query_text, course.name, conversation_context)
            maybe_save_to_session(session_id, query_text, response)
            {:ok, response, :fallback}
        end
    end
  end

  defp search_relevant_content(course_id, query_text, query_embedding) do
    Logger.info("Searching for query: '#{query_text}' in course #{course_id}")

    # Semantic search using Chroma
    semantic_results =
      case VectorStore.similarity_search(course_id, query_embedding, @max_context_chunks) do
        {:ok, results} ->
          Logger.info("Vector search found #{length(results)} results")
          convert_chroma_results_to_chunks(results)

        {:error, reason} ->
          Logger.warning("Vector search failed: #{reason}")
          []
      end

    # Keyword search for exact matches in SQLite
    keyword_chunks = search_by_keywords(course_id, query_text)
    Logger.info("Keyword search found #{length(keyword_chunks)} results")

    # Combine and deduplicate results
    combined_results = combine_search_results(semantic_results, keyword_chunks)
    Logger.info("Combined search results: #{length(combined_results)} chunks")
    combined_results
  end

  defp convert_chroma_results_to_chunks(chroma_results) do
    # Get unique document IDs to fetch document info
    document_ids =
      chroma_results
      |> Enum.map(& &1.metadata["document_id"])
      |> Enum.uniq()

    # Fetch document information
    documents =
      case document_ids do
        [] ->
          %{}

        ids ->
          import Ecto.Query

          from(d in StudyBot.Documents.Document, where: d.id in ^ids)
          |> StudyBot.Repo.all()
          |> Enum.into(%{}, &{&1.id, &1})
      end

    chroma_results
    |> Enum.map(fn result ->
      document_id = result.metadata["document_id"]
      document = Map.get(documents, document_id)

      # Convert Chroma result back to DocumentChunk-like structure
      %{
        id: document_id <> "_" <> to_string(result.metadata["chunk_index"]),
        document_id: document_id,
        chunk_index: result.metadata["chunk_index"],
        course_id: result.metadata["course_id"],
        content: result.content,
        token_count: result.metadata["token_count"],
        start_char: result.metadata["start_char"],
        end_char: result.metadata["end_char"],
        distance: result.distance,
        document: document
      }
    end)
  end

  defp search_by_keywords(course_id, query_text) do
    keywords = extract_keywords(query_text)
    Logger.info("Extracted keywords: #{inspect(keywords)}")

    if length(keywords) > 0 do
      import Ecto.Query

      # Simple approach: search for any keyword with individual queries
      results =
        Enum.flat_map(keywords, fn keyword ->
          query =
            from c in DocumentChunk,
              join: d in assoc(c, :document),
              where: c.course_id == ^course_id,
              where: fragment("lower(?) LIKE lower(?)", c.content, ^"%#{keyword}%"),
              preload: [document: d],
              limit: 2

          StudyBot.Repo.all(query)
        end)
        |> Enum.uniq_by(& &1.id)
        |> Enum.take(@max_context_chunks)

      Logger.info("Keyword search for #{inspect(keywords)} found #{length(results)} results")
      results
    else
      Logger.info("No keywords extracted, skipping keyword search")
      []
    end
  rescue
    e ->
      Logger.warning("Keyword search failed: #{inspect(e)}")
      []
  end

  defp extract_keywords(text) do
    text
    |> String.downcase()
    |> String.split(~r/\W+/, trim: true)
    # Changed from > 3 to >= 3 to include "soup"
    |> Enum.filter(&(String.length(&1) >= 3))
    |> Enum.take(5)
  end

  defp combine_search_results(semantic_chunks, keyword_chunks) do
    all_chunks = (semantic_chunks ++ keyword_chunks) |> Enum.uniq_by(& &1.id)

    # Prioritize semantic results but include keyword matches
    semantic_ids = MapSet.new(semantic_chunks, & &1.id)

    {semantic_results, keyword_only} =
      Enum.split_with(all_chunks, &MapSet.member?(semantic_ids, &1.id))

    (semantic_results ++ keyword_only)
    |> Enum.take(@max_context_chunks)
  end

  defp generate_rag_response(query_text, chunks, course_name, conversation_context) do
    context = build_context_from_chunks(chunks)

    system_prompt = """
    You are a helpful study assistant for the course "#{course_name}".  

    You are an insightful, encouraging tutor who combines meticulous clarity with genuine enthusiasm and gentle humor.

    Answer the user's question based on the provided context from course materials and the conversation history.

    Your goal is to help the student understand the material.  Add clarification and explain the source material, don't just quote the material.  Provide your answers in language appropriate for a first year community college student.

    Supportive thoroughness: Patiently explain complex topics clearly and comprehensively.

    Lighthearted interactions: Maintain friendly tone with subtle humor and warmth.

    Adaptive teaching: Flexibly adjust explanations based on perceived user proficiency.

    Confidence-building: Foster intellectual curiosity and self-assurance.    

    IMPORTANT: When you reference information from the context, always cite your sources using the format [Source X] where X is the source number. For example: "According to the documentation [Source 1], software requirements must be traceable [Source 2]."

    If the context doesn't contain enough information to answer the question, 
    say so clearly and provide what information you can.

    Consider the conversation history when answering. Reference previous questions and answers when relevant to provide continuity and build upon earlier explanations.

    Format the response using Markdown syntax.

    Context from course materials:
    #{context}
    """

    # Build message list with conversation history
    messages =
      [
        %{role: "system", content: system_prompt}
      ] ++
        conversation_context ++
        [
          %{role: "user", content: query_text}
        ]

    case Client.chat_completion(messages) do
      {:ok, response} ->
        # Add source list to the response
        citation_list = build_citation_list(chunks)
        enhanced_response = response <> "\n\n" <> citation_list
        {:ok, enhanced_response}

      error ->
        error
    end
  end

  defp generate_fallback_response(query_text, course_name, conversation_context) do
    system_prompt = """
    You are a helpful study assistant for the course "#{course_name}". 
    The user asked a question, but I couldn't find relevant information in the course materials.
    Provide a helpful general response to their question, but clearly state that this information 
    is not from the course materials and they should verify with their instructor or textbook.

    Consider the conversation history when answering to maintain continuity with previous responses.
    """

    # Build message list with conversation history
    messages =
      [
        %{role: "system", content: system_prompt}
      ] ++
        conversation_context ++
        [
          %{role: "user", content: query_text}
        ]

    case Client.chat_completion(messages) do
      {:ok, response} ->
        "⚠️ **Information not found in course materials**\n\n" <>
          response <> "\n\n**Sources:** General knowledge (not from course documents)"

      {:error, _} ->
        "I'm sorry, I couldn't find information about this topic in your course materials, and I'm currently unable to provide a general response. Please consult your textbook or instructor for help with this question.\n\n**Sources:** None available"
    end
  end

  defp build_context_from_chunks(chunks) do
    Logger.info("Building context from #{length(chunks)} chunks")

    context =
      chunks
      |> Enum.with_index(1)
      |> Enum.map(fn {chunk, index} ->
        chunk_preview = String.slice(chunk.content, 0, 100) <> "..."
        Logger.info("  Chunk #{index}: #{chunk_preview}")

        # Get document filename for citation
        document_name =
          case chunk do
            %{document: %{original_filename: filename}} when is_binary(filename) ->
              filename

            %{document_id: doc_id} when is_binary(doc_id) ->
              "Document #{String.slice(doc_id, 0, 8)}"

            _ ->
              "Unknown Document"
          end

        "Source #{index} (#{document_name}):\n#{String.trim(chunk.content)}\n"
      end)
      |> Enum.join("\n---\n\n")

    Logger.info("Context built, length: #{String.length(context)} characters")
    context
  end

  defp build_citation_list(chunks) do
    # Group chunks by document and collect unique documents with their source numbers
    documents_with_sources =
      chunks
      |> Enum.with_index(1)
      |> Enum.reduce(%{}, fn {chunk, index}, acc ->
        document_name =
          case chunk do
            %{document: %{original_filename: filename}} when is_binary(filename) ->
              filename

            %{document_id: doc_id} when is_binary(doc_id) ->
              "Document #{String.slice(doc_id, 0, 8)}"

            _ ->
              "Unknown Document"
          end

        document_id =
          case chunk do
            %{document: %{id: id}} -> id
            %{document_id: id} -> id
            _ -> "unknown"
          end

        # Track which sources reference each document
        current_sources = Map.get(acc, document_id, %{name: document_name, sources: []})
        updated_sources = %{current_sources | sources: [index | current_sources.sources]}

        Map.put(acc, document_id, updated_sources)
      end)

    # Build citation list with source ranges
    citations =
      documents_with_sources
      |> Enum.map(fn {_doc_id, %{name: document_name, sources: source_numbers}} ->
        sorted_sources = Enum.sort(source_numbers)

        source_range =
          case sorted_sources do
            [single] ->
              "Source #{single}"

            multiple ->
              ranges = build_source_ranges(multiple)
              "Sources #{ranges}"
          end

        "#{source_range}: #{document_name}"
      end)
      |> Enum.sort()
      |> Enum.join("\n")

    "**Sources:**\n#{citations}"
  end

  defp build_source_ranges(numbers) do
    numbers
    |> Enum.sort()
    |> Enum.chunk_while(
      [],
      fn x, acc ->
        case acc do
          [] -> {:cont, [x]}
          [last | _] when x == last + 1 -> {:cont, [x | acc]}
          range -> {:cont, Enum.reverse(range), [x]}
        end
      end,
      fn acc -> {:cont, Enum.reverse(acc), []} end
    )
    |> Enum.map(fn
      [single] -> "#{single}"
      [first, second] -> "#{first}, #{second}"
      range -> "#{List.first(range)}-#{List.last(range)}"
    end)
    |> Enum.join(", ")
  end

  defp get_conversation_context(nil), do: []

  defp get_conversation_context(session_id) do
    case Chat.get_session(session_id) do
      %Chat.ChatSession{} = session ->
        messages = Chat.get_messages(session)

        # Convert last few messages to conversation context, excluding current query
        # Limit to last 6 messages (3 exchanges) to keep context manageable
        messages
        |> Enum.take(-6)
        |> Enum.map(fn message ->
          %{
            role: message["role"],
            content: clean_message_content(message["content"])
          }
        end)

      nil ->
        Logger.warning("Session #{session_id} not found for context")
        []
    end
  end

  defp clean_message_content(content) do
    # Remove response indicators and citations for cleaner context
    content
    |> String.replace(~r/^[🔄⚠️❌]\s*/, "")
    |> String.replace(~r/\*\*Information not found in course materials\*\*\n\n/, "")
    |> String.replace(~r/\n\n\*\*Sources:\*\*\n.*$/s, "")
    |> String.trim()
  end

  defp maybe_save_to_session(nil, _query, _response), do: :ok

  defp maybe_save_to_session(session_id, query_text, response) do
    case Chat.get_session(session_id) do
      %Chat.ChatSession{} = session ->
        user_message = %{
          "role" => "user",
          "content" => query_text,
          "timestamp" => DateTime.utc_now()
        }

        assistant_message = %{
          "role" => "assistant",
          "content" => response,
          "timestamp" => DateTime.utc_now()
        }

        Logger.info(
          "Saving user message to session #{session_id}: #{String.slice(query_text, 0, 50)}..."
        )

        with {:ok, updated_session} <- Chat.add_message(session, user_message) do
          Logger.info("User message saved successfully")

          Logger.info(
            "Saving assistant message to session #{session_id}: #{String.slice(response, 0, 50)}..."
          )

          case Chat.add_message(updated_session, assistant_message) do
            {:ok, _} ->
              Logger.info("Assistant message saved successfully")
              :ok

            error ->
              Logger.warning("Failed to save assistant message: #{inspect(error)}")
              :ok
          end
        else
          error ->
            Logger.warning("Failed to save user message to session: #{inspect(error)}")
            :ok
        end

      nil ->
        Logger.warning("Session #{session_id} not found")
        :ok
    end
  end

  defp get_course(course_id) do
    case Courses.get_course(course_id) do
      %Courses.Course{} = course -> {:ok, course}
      nil -> {:error, "Course not found"}
    end
  end

  # Utility functions for course setup
  def setup_course_with_documents(course_name, file_paths) do
    with {:ok, course} <- Courses.create_course(%{name: course_name}) do
      Enum.each(file_paths, fn file_path ->
        filename = Path.basename(file_path)

        case Documents.process_uploaded_file(file_path, course.id, filename) do
          {:ok, _document} ->
            Logger.info("Successfully processed file #{filename}")

          {:error, reason} ->
            Logger.error("Failed to process file #{filename}: #{inspect(reason)}")
        end
      end)

      {:ok, course}
    end
  end
end
