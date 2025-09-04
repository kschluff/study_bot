defmodule StudyBot.RAG do
  @moduledoc """
  The RAG (Retrieval-Augmented Generation) system that combines document search,
  semantic caching, and response generation.
  """

  alias StudyBot.{Courses, Documents, Embeddings, Cache, Chat}
  alias StudyBot.Documents.DocumentChunk
  alias StudyBot.AI.Client

  require Logger

  @max_context_chunks 5

  def process_query(course_id, query_text, session_id \\ nil) do
    with {:ok, course} <- get_course(course_id),
         {:ok, query_embedding} <- Embeddings.generate_query_embedding(query_text) do
      
      case Cache.lookup_cache(course_id, query_text, query_embedding) do
        {:hit, cached_response} ->
          Logger.info("Cache hit for query in course #{course.name}")
          {:ok, cached_response, :cached}

        :miss ->
          Logger.info("Cache miss, processing query for course #{course.name}")
          process_query_with_retrieval(course, query_text, query_embedding, session_id)
      end
    else
      error -> error
    end
  end

  defp process_query_with_retrieval(course, query_text, query_embedding, session_id) do
    # Perform hybrid search
    relevant_chunks = search_relevant_content(course.id, query_text, query_embedding)
    
    case relevant_chunks do
      [] ->
        # No relevant content found, use fallback LLM
        response = generate_fallback_response(query_text, course.name)
        Cache.cache_response(course.id, query_text, query_embedding, response)
        {:ok, response, :fallback}

      chunks when chunks != [] ->
        # Generate RAG response with context
        case generate_rag_response(query_text, chunks, course.name) do
          {:ok, response} ->
            Cache.cache_response(course.id, query_text, query_embedding, response, chunks)
            maybe_save_to_session(session_id, query_text, response)
            {:ok, response, :rag}

          {:error, reason} ->
            Logger.error("Failed to generate RAG response: #{reason}")
            response = generate_fallback_response(query_text, course.name)
            {:ok, response, :fallback}
        end
    end
  end

  defp search_relevant_content(course_id, query_text, query_embedding) do
    # Semantic search using embeddings
    semantic_chunks = Embeddings.search_similar_chunks(course_id, query_embedding, @max_context_chunks)
    
    # Keyword search for exact matches
    keyword_chunks = search_by_keywords(course_id, query_text)
    
    # Combine and deduplicate results
    combine_search_results(semantic_chunks, keyword_chunks)
  end

  defp search_by_keywords(course_id, query_text) do
    keywords = extract_keywords(query_text)
    
    if length(keywords) > 0 do
      # Search for chunks containing keywords
      keyword_pattern = Enum.join(keywords, "|")
      
      import Ecto.Query
      
      query = from c in DocumentChunk,
                   where: c.course_id == ^course_id,
                   where: fragment("? REGEXP ?", c.content, ^keyword_pattern),
                   limit: @max_context_chunks
      
      StudyBot.Repo.all(query)
    else
      []
    end
  rescue
    _ -> []
  end

  defp extract_keywords(text) do
    text
    |> String.downcase()
    |> String.split(~r/\W+/, trim: true)
    |> Enum.filter(&(String.length(&1) > 3))
    |> Enum.take(5)
  end

  defp combine_search_results(semantic_chunks, keyword_chunks) do
    all_chunks = (semantic_chunks ++ keyword_chunks) |> Enum.uniq_by(& &1.id)
    
    # Prioritize semantic results but include keyword matches
    semantic_ids = MapSet.new(semantic_chunks, & &1.id)
    
    {semantic_results, keyword_only} = Enum.split_with(all_chunks, &MapSet.member?(semantic_ids, &1.id))
    
    (semantic_results ++ keyword_only)
    |> Enum.take(@max_context_chunks)
  end

  defp generate_rag_response(query_text, chunks, course_name) do
    context = build_context_from_chunks(chunks)
    
    system_prompt = """
    You are a helpful study assistant for the course "#{course_name}". 
    Answer the user's question based on the provided context from course materials.
    If the context doesn't contain enough information to answer the question, 
    say so clearly and provide what information you can from the context.
    
    Context from course materials:
    #{context}
    """

    messages = [
      %{role: "system", content: system_prompt},
      %{role: "user", content: query_text}
    ]

    case Client.chat_completion(messages) do
      {:ok, response} -> {:ok, response}
      error -> error
    end
  end

  defp generate_fallback_response(query_text, course_name) do
    system_prompt = """
    You are a helpful study assistant for the course "#{course_name}". 
    The user asked a question, but I couldn't find relevant information in the course materials.
    Provide a helpful general response to their question, but clearly state that this information 
    is not from the course materials and they should verify with their instructor or textbook.
    """

    messages = [
      %{role: "system", content: system_prompt},
      %{role: "user", content: query_text}
    ]

    case Client.chat_completion(messages) do
      {:ok, response} -> 
        "⚠️ **Information not found in course materials**\n\n" <> response
      {:error, _} ->
        "I'm sorry, I couldn't find information about this topic in your course materials, and I'm currently unable to provide a general response. Please consult your textbook or instructor for help with this question."
    end
  end

  defp build_context_from_chunks(chunks) do
    chunks
    |> Enum.with_index(1)
    |> Enum.map(fn {chunk, index} ->
      "Source #{index}:\n#{String.trim(chunk.content)}\n"
    end)
    |> Enum.join("\n---\n\n")
  end


  defp maybe_save_to_session(nil, _query, _response), do: :ok
  defp maybe_save_to_session(session_id, query_text, response) do
    case Chat.get_session(session_id) do
      %Chat.ChatSession{} = session ->
        user_message = %{role: "user", content: query_text, timestamp: DateTime.utc_now()}
        assistant_message = %{role: "assistant", content: response, timestamp: DateTime.utc_now()}
        
        with {:ok, _} <- Chat.add_message(session, user_message),
             {:ok, _} <- Chat.add_message(session, assistant_message) do
          :ok
        else
          error ->
            Logger.warning("Failed to save messages to session: #{inspect(error)}")
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


  # Background processing for document embeddings
  def process_document_embeddings(document_id) do
    Task.start(fn ->
      Logger.info("Starting embedding generation for document #{document_id}")
      Embeddings.generate_embeddings_for_document(document_id)
      Logger.info("Completed embedding generation for document #{document_id}")
    end)
  end

  # Utility functions for course setup
  def setup_course_with_documents(course_name, file_paths) do
    with {:ok, course} <- Courses.create_course(%{name: course_name}) do
      Enum.each(file_paths, fn file_path ->
        filename = Path.basename(file_path)
        case Documents.process_uploaded_file(file_path, course.id, filename) do
          {:ok, document} ->
            # Start embedding generation
            process_document_embeddings(document.id)
            
          {:error, reason} ->
            Logger.error("Failed to process file #{filename}: #{inspect(reason)}")
        end
      end)
      
      {:ok, course}
    end
  end
end