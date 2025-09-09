defmodule StudyBotWeb.ChatLive do
  use StudyBotWeb, :live_view

  alias StudyBot.{Courses, Chat, RAG}

  @impl true
  def mount(%{"id" => course_id}, _session, socket) do
    case Courses.get_course(course_id) do
      %Courses.Course{} = course ->
        sessions = Chat.list_sessions(course.id)

        {:ok,
         socket
         |> assign(:course, course)
         |> assign(:sessions, sessions)
         |> assign(:current_session, nil)
         |> assign(:messages, [])
         |> assign(:query, "")
         |> assign(:loading, false)
         |> assign(:page_title, "Chat - #{course.name}")}

      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Course not found")
         |> push_navigate(to: ~p"/")}
    end
  end

  @impl true
  def handle_event("send_message", %{"query" => query}, socket) when query != "" do
    course = socket.assigns.course
    current_session = socket.assigns.current_session

    # Create session if none exists
    session =
      case current_session do
        nil ->
          {:ok, new_session} = Chat.create_session(%{course_id: course.id})
          new_session

        session ->
          session
      end

    # Add user message to UI immediately
    user_message = %{
      "role" => "user",
      "content" => String.trim(query),
      "timestamp" => DateTime.utc_now()
    }

    updated_messages = socket.assigns.messages ++ [user_message]

    # Process query asynchronously
    send(self(), {:process_query, query, session.id})

    {:noreply,
     socket
     |> assign(:messages, updated_messages)
     |> assign(:current_session, session)
     |> assign(:query, "")
     |> assign(:loading, true)}
  end

  @impl true
  def handle_event("send_message", %{"query" => ""}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_query", %{"query" => query}, socket) do
    {:noreply, assign(socket, :query, query)}
  end

  @impl true
  def handle_event("select_session", %{"session_id" => session_id}, socket) do
    session = Chat.get_session!(session_id)
    messages = Chat.get_messages(session)

    {:noreply,
     socket
     |> assign(:current_session, session)
     |> assign(:messages, messages)}
  end

  @impl true
  def handle_event("new_session", _params, socket) do
    {:noreply,
     socket
     |> assign(:current_session, nil)
     |> assign(:messages, [])}
  end

  @impl true
  def handle_event("delete_session", %{"session_id" => session_id}, socket) do
    session = Chat.get_session!(session_id)
    Chat.delete_session(session)

    sessions = Chat.list_sessions(socket.assigns.course.id)

    # If deleted session was current, reset
    {current_session, messages} =
      if socket.assigns.current_session && socket.assigns.current_session.id == session_id do
        {nil, []}
      else
        {socket.assigns.current_session, socket.assigns.messages}
      end

    {:noreply,
     socket
     |> assign(:sessions, sessions)
     |> assign(:current_session, current_session)
     |> assign(:messages, messages)
     |> put_flash(:info, "Chat session deleted")}
  end

  @impl true
  def handle_info({:process_query, query, session_id}, socket) do
    course_id = socket.assigns.course.id

    case RAG.process_query(course_id, query, session_id) do
      {:ok, response, source} ->
        # Add response indicator based on source
        response_with_indicator =
          case source do
            :cached -> "🔄 " <> response
            :fallback -> "⚠️ " <> response
            :rag -> response
          end

        assistant_message = %{
          "role" => "assistant",
          "content" => response_with_indicator,
          "timestamp" => DateTime.utc_now(),
          "source" => to_string(source)
        }

        updated_messages = socket.assigns.messages ++ [assistant_message]
        sessions = Chat.list_sessions(course_id)

        {:noreply,
         socket
         |> assign(:messages, updated_messages)
         |> assign(:sessions, sessions)
         |> assign(:loading, false)}

      {:error, reason} ->
        error_message = %{
          "role" => "assistant",
          "content" => "❌ Sorry, I encountered an error: #{reason}",
          "timestamp" => DateTime.utc_now(),
          "source" => "error"
        }

        updated_messages = socket.assigns.messages ++ [error_message]

        {:noreply,
         socket
         |> assign(:messages, updated_messages)
         |> assign(:loading, false)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app_full_width flash={@flash}>
      <div class="flex h-screen bg-gray-100">
        <!-- Sidebar -->
        <div class="w-64 lg:w-72 bg-white shadow-lg flex flex-col">
          <!-- Header -->
          <div class="p-6 border-b bg-gradient-to-r from-blue-600 to-indigo-600 text-white">
            <div class="flex items-center justify-between mb-4">
              <.link navigate={~p"/"} class="text-white hover:text-blue-200">
                <.icon name="hero-arrow-left" class="w-5 h-5" />
              </.link>
              <button
                phx-click="new_session"
                class="bg-white/20 hover:bg-white/30 text-white px-3 py-1 rounded-lg text-sm transition-colors duration-200"
              >
                <.icon name="hero-plus" class="w-4 h-4 inline mr-1" /> New Chat
              </button>
            </div>

            <div>
              <h2 class="font-semibold text-lg truncate" title={@course.name}>
                {@course.name}
              </h2>
              <div class="flex items-center gap-4 mt-2 text-sm text-blue-100">
                <span>
                  {length(@sessions)} sessions
                </span>
                <.link
                  navigate={~p"/courses/#{@course.id}/documents"}
                  class="hover:text-white transition-colors"
                >
                  <.icon name="hero-document-text" class="w-4 h-4 inline mr-1" /> Documents
                </.link>
              </div>
            </div>
          </div>
          
    <!-- Sessions List -->
          <div class="flex-1 overflow-y-auto">
            <%= if @sessions == [] do %>
              <div class="p-6 text-center text-gray-500">
                <div class="text-4xl mb-2">💭</div>
                <p class="text-sm">No chat sessions yet.<br />Ask a question to get started!</p>
              </div>
            <% else %>
              <div class="p-4 space-y-2">
                <%= for session <- @sessions do %>
                  <div class={[
                    "p-3 rounded-lg cursor-pointer transition-colors duration-200",
                    if(@current_session && @current_session.id == session.id,
                      do: "bg-blue-100 border border-blue-200",
                      else: "hover:bg-gray-100"
                    )
                  ]}>
                    <div class="flex justify-between items-start">
                      <div
                        phx-click="select_session"
                        phx-value-session_id={session.id}
                        class="flex-1 min-w-0"
                      >
                        <p class="text-sm font-medium text-gray-900 truncate">
                          {session.title || "New Chat"}
                        </p>
                        <p class="text-xs text-gray-500 mt-1">
                          {Calendar.strftime(session.updated_at, "%b %d, %H:%M")}
                        </p>
                      </div>

                      <button
                        phx-click="delete_session"
                        phx-value-session_id={session.id}
                        data-confirm="Delete this chat session?"
                        class="text-gray-400 hover:text-red-500 p-1"
                      >
                        <.icon name="hero-trash" class="w-3 h-3" />
                      </button>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
        
    <!-- Main Chat Area -->
        <div class="flex-1 flex flex-col relative">
          <!-- Chat Messages -->
          <div
            id="messages-container"
            class="flex-1 overflow-y-auto p-2 md:p-4 space-y-1"
            phx-hook="ScrollToBottom"
          >
            <%= if @messages == [] do %>
              <div class="text-center py-12">
                <div class="text-6xl mb-4">🤖</div>
                <h3 class="text-xl font-semibold text-gray-700 mb-2">
                  Ready to help you study!
                </h3>
                <p class="text-gray-600 max-w-md mx-auto">
                  Ask questions about your {@course.name} course materials.
                  I'll search through your documents to provide accurate answers.
                </p>
              </div>
            <% else %>
              <%= for message <- @messages do %>
                <div class={[
                  "flex mb-1",
                  if(message["role"] == "user", do: "justify-end", else: "justify-start")
                ]}>
                  <div class={[
                    "max-w-4xl lg:max-w-5xl px-2 py-1 mx-1 rounded-lg",
                    case message["role"] do
                      "user" ->
                        "bg-blue-600 text-white"

                      "assistant" ->
                        case Map.get(message, "source", "rag") do
                          "error" -> "bg-red-100 border border-red-200 text-red-800"
                          "fallback" -> "bg-yellow-100 border border-yellow-200 text-yellow-800"
                          "cached" -> "bg-green-100 border border-green-200 text-green-800"
                          _ -> "bg-white border border-gray-200 text-gray-800"
                        end
                    end
                  ]}>
                    <div class="whitespace-pre-wrap text-sm leading-tight">
                      {message["content"]}
                    </div>
                  </div>
                </div>
              <% end %>
            <% end %>

            <%= if @loading do %>
              <div class="flex justify-start mb-1">
                <div class="bg-white border border-gray-200 text-gray-800 max-w-4xl lg:max-w-5xl px-2 py-1 mx-1 rounded-lg">
                  <div class="flex items-center space-x-2">
                    <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-blue-600"></div>
                    <span class="text-sm">Thinking...</span>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
          
    <!-- Scroll to Bottom Button -->
          <div
            id="scroll-to-bottom-container"
            class="absolute bottom-20 right-8 hidden"
            phx-hook="ScrollButton"
          >
            <button
              id="scroll-to-bottom-btn"
              class="bg-blue-600 hover:bg-blue-700 text-white p-3 rounded-full shadow-lg transition-colors duration-200"
              title="Scroll to bottom"
            >
              <.icon name="hero-chevron-down" class="w-5 h-5" />
            </button>
          </div>
          
    <!-- Message Input -->
          <div class="border-t bg-white p-4 md:p-6">
            <form phx-submit="send_message" class="flex space-x-4">
              <input
                type="text"
                name="query"
                value={@query}
                phx-change="update_query"
                placeholder="Ask a question about your course materials..."
                disabled={@loading}
                autocomplete="off"
                class="flex-1 border border-gray-300 rounded-lg px-4 py-3 text-gray-900 placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent disabled:opacity-50"
                autofocus
              />
              <button
                type="submit"
                disabled={@loading or @query == ""}
                class="bg-blue-600 hover:bg-blue-700 disabled:bg-gray-400 text-white px-6 py-3 rounded-lg font-medium transition-colors duration-200"
              >
                <%= if @loading do %>
                  <.icon name="hero-arrow-path" class="w-5 h-5 animate-spin" />
                <% else %>
                  <.icon name="hero-paper-airplane" class="w-5 h-5" />
                <% end %>
              </button>
            </form>

            <p class="text-xs text-gray-500 mt-2 text-center">
              💡 Tip: Upload course documents to get more accurate answers
            </p>
          </div>
        </div>
      </div>
    </Layouts.app_full_width>
    """
  end

  defp format_timestamp(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%H:%M")
  end

  defp format_timestamp(timestamp_string) when is_binary(timestamp_string) do
    case DateTime.from_iso8601(timestamp_string) do
      {:ok, datetime, _offset} -> Calendar.strftime(datetime, "%H:%M")
      {:error, _} -> "??:??"
    end
  end

  defp format_timestamp(_), do: "??:??"
end
