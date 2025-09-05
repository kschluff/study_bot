defmodule StudyBotWeb.DocumentsLive do
  use StudyBotWeb, :live_view

  alias StudyBot.{Courses, Documents}

  @impl true
  def mount(%{"course_id" => course_id}, _session, socket) do
    case Courses.get_course(course_id) do
      %Courses.Course{} = course ->
        documents = Documents.list_documents(course.id)

        {:ok,
         socket
         |> assign(:course, course)
         |> assign(:documents, documents)
         |> assign(:uploaded_files, [])
         |> assign(:page_title, "Documents - #{course.name}")
         |> allow_upload(:documents,
           accept: ~w(.txt .pdf),
           max_entries: 5,
           max_file_size: Application.get_env(:study_bot, :max_file_size, 50_000_000)
         )}

      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Course not found")
         |> push_navigate(to: ~p"/")}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
  end

  defp apply_action(socket, :upload, _params) do
    socket
  end

  @impl true
  def handle_event("validate_upload", _params, socket) do
    # LiveView uploads require validation to function properly
    # Check for upload errors and handle them gracefully
    socket = 
      case upload_errors(socket.assigns.uploads.documents) do
        [] -> socket
        errors -> 
          IO.inspect(errors, label: "Upload validation errors")
          socket
      end
    
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :documents, ref)}
  end

  @impl true
  def handle_event("upload_documents", _params, socket) do
    course = socket.assigns.course

    uploaded_results =
      consume_uploaded_entries(socket, :documents, fn %{path: path}, entry ->
        # Save the uploaded file to a temporary location
        dest_path = Path.join(System.tmp_dir(), "upload_#{entry.uuid}_#{entry.client_name}")
        File.cp!(path, dest_path)

        case Documents.process_uploaded_file(dest_path, course.id, entry.client_name) do
          {:ok, document} ->
            {:ok, document}

          {:error, reason} ->
            {:error, reason}
        end
      end)

    #    {successful, failed} = 
    #      uploaded_results
    #      |> Enum.split_with(fn
    #        # {:ok, _document} -> true
    #        {:error, _reason} -> false
    #      end)

    socket =
      if length(uploaded_results) > 0 do
        documents = Documents.list_documents(course.id)

        socket
        |> assign(:documents, documents)
        |> put_flash(:info, "#{length(uploaded_results)} document(s) uploaded successfully!")
      else
        socket
      end

    #    socket =
    #      if length(failed) > 0 do
    #        error_messages = Enum.map(failed, fn {:error, reason} -> reason end)
    #        put_flash(socket, :error, "Failed to upload: #{Enum.join(error_messages, ", ")}")
    #      else
    #        socket
    #      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("delete_document", %{"id" => id}, socket) do
    document = Documents.get_document!(id)
    {:ok, _} = Documents.delete_document(document)

    documents = Documents.list_documents(socket.assigns.course.id)

    {:noreply,
     socket
     |> assign(:documents, documents)
     |> put_flash(:info, "Document deleted successfully")}
  end

  @impl true
  def handle_event("reprocess_document", %{"id" => _id}, socket) do
    # This would trigger reprocessing of a failed document
    # Implementation would depend on storing the original file path
    {:noreply, put_flash(socket, :info, "Document reprocessing started")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app_wide flash={@flash}>
      <div class="min-h-screen bg-gray-50">
        <div class="container mx-auto px-6 py-8">
          <!-- Header -->
          <div class="mb-8">
            <div class="flex items-center gap-4 mb-4">
              <.link
                navigate={~p"/courses/#{@course.id}"}
                class="text-gray-600 hover:text-gray-800"
              >
                <.icon name="hero-arrow-left" class="w-5 h-5" />
              </.link>

              <div>
                <h1 class="text-2xl font-bold text-gray-800">
                  Course Documents
                </h1>
                <p class="text-gray-600">
                  {@course.name}
                </p>
              </div>
            </div>

            <div class="flex justify-between items-center">
              <div class="flex items-center gap-6 text-sm text-gray-600">
                <span>
                  {length(@documents)} total documents
                </span>
                <span>
                  {Enum.count(@documents, &(&1.status == "processed"))} processed
                </span>
                <span>
                  {Enum.count(@documents, &(&1.status == "failed"))} failed
                </span>
              </div>

              <.link
                navigate={~p"/courses/#{@course.id}/documents/upload"}
                class="bg-blue-600 hover:bg-blue-700 text-white px-6 py-2 rounded-lg font-medium transition-colors duration-200"
              >
                <.icon name="hero-document-plus" class="w-5 h-5 inline mr-2" /> Upload Documents
              </.link>
            </div>
          </div>

          <%= if @live_action == :upload do %>
            <!-- Upload Form -->
            <div class="bg-white rounded-xl shadow-lg p-8 mb-8">
              <h2 class="text-xl font-semibold mb-6">Upload Course Documents</h2>

              <form phx-submit="upload_documents" phx-change="validate_upload" id="upload-form">
                <div class="mb-6">
                  <div
                    class="border-2 border-dashed border-gray-300 rounded-lg p-8 text-center hover:border-gray-400 transition-colors duration-200"
                    phx-drop-target={@uploads.documents.ref}
                  >
                    <.icon name="hero-document-arrow-up" class="w-12 h-12 text-gray-400 mx-auto mb-4" />

                    <div class="space-y-2">
                      <p class="text-lg font-medium text-gray-700">
                        Drop files here or click to browse
                      </p>
                      <p class="text-sm text-gray-500">
                        Supports: PDF, TXT files (max 50MB each, up to 5 files)
                      </p>
                    </div>

                    <label class="cursor-pointer">
                      <.live_file_input upload={@uploads.documents} class="sr-only" />
                      <span class="mt-4 inline-block bg-blue-600 hover:bg-blue-700 text-white px-6 py-2 rounded-lg font-medium transition-colors duration-200">
                        Choose Files
                      </span>
                    </label>
                  </div>
                  
    <!-- Upload Progress -->
                  <%= for entry <- @uploads.documents.entries do %>
                    <div class="mt-4 p-4 border border-gray-200 rounded-lg">
                      <div class="flex justify-between items-center mb-2">
                        <span class="text-sm font-medium text-gray-700">
                          {entry.client_name}
                        </span>
                        <div class="flex items-center gap-2">
                          <span class="text-xs text-gray-500">
                            {div(entry.client_size, 1024)} KB
                          </span>
                          <button
                            type="button"
                            phx-click="cancel_upload"
                            phx-value-ref={entry.ref}
                            class="text-red-500 hover:text-red-700"
                          >
                            <.icon name="hero-x-mark" class="w-4 h-4" />
                          </button>
                        </div>
                      </div>

                      <div class="w-full bg-gray-200 rounded-full h-2">
                        <div
                          class="bg-blue-600 h-2 rounded-full transition-all duration-300"
                          style={"width: #{entry.progress}%"}
                        >
                        </div>
                      </div>

                      <%= for err <- upload_errors(@uploads.documents, entry) do %>
                        <p class="text-red-500 text-sm mt-1">
                          {error_to_string(err)}
                        </p>
                      <% end %>
                    </div>
                  <% end %>
                </div>

                <div class="flex justify-end gap-3">
                  <.link
                    navigate={~p"/courses/#{@course.id}/documents"}
                    class="px-6 py-2 text-gray-600 hover:text-gray-800 font-medium"
                  >
                    Cancel
                  </.link>

                  <button
                    type="submit"
                    disabled={@uploads.documents.entries == []}
                    class="bg-blue-600 hover:bg-blue-700 disabled:bg-gray-400 text-white px-6 py-2 rounded-lg font-medium transition-colors duration-200"
                  >
                    Upload Documents
                  </button>
                </div>
              </form>
            </div>
          <% end %>
          
    <!-- Documents List -->
          <%= if @documents == [] do %>
            <div class="bg-white rounded-xl shadow-lg p-12 text-center">
              <div class="text-6xl mb-6">📚</div>
              <h3 class="text-xl font-semibold text-gray-700 mb-3">
                No documents uploaded yet
              </h3>
              <p class="text-gray-600 mb-6 max-w-md mx-auto">
                Upload your course materials like textbooks, lecture notes, or PDFs
                to enable AI-powered question answering.
              </p>
              <.link
                navigate={~p"/courses/#{@course.id}/documents/upload"}
                class="bg-blue-600 hover:bg-blue-700 text-white px-6 py-3 rounded-lg font-medium transition-colors duration-200"
              >
                Upload Your First Document
              </.link>
            </div>
          <% else %>
            <div class="bg-white rounded-xl shadow-lg overflow-hidden">
              <div class="overflow-x-auto">
                <table class="w-full">
                  <thead class="bg-gray-50 border-b border-gray-200">
                    <tr>
                      <th class="text-left px-6 py-4 text-sm font-semibold text-gray-700">
                        Document
                      </th>
                      <th class="text-left px-6 py-4 text-sm font-semibold text-gray-700">
                        Type
                      </th>
                      <th class="text-left px-6 py-4 text-sm font-semibold text-gray-700">
                        Size
                      </th>
                      <th class="text-left px-6 py-4 text-sm font-semibold text-gray-700">
                        Status
                      </th>
                      <th class="text-left px-6 py-4 text-sm font-semibold text-gray-700">
                        Uploaded
                      </th>
                      <th class="text-right px-6 py-4 text-sm font-semibold text-gray-700">
                        Actions
                      </th>
                    </tr>
                  </thead>

                  <tbody class="divide-y divide-gray-200">
                    <%= for document <- @documents do %>
                      <tr class="hover:bg-gray-50">
                        <td class="px-6 py-4">
                          <div class="flex items-center">
                            <.icon
                              name={document_icon(document.file_type)}
                              class="w-5 h-5 text-gray-400 mr-3"
                            />
                            <div>
                              <p class="font-medium text-gray-900">
                                {document.original_filename}
                              </p>
                              <%= if document.error_message do %>
                                <p class="text-sm text-red-600 mt-1">
                                  {document.error_message}
                                </p>
                              <% end %>
                            </div>
                          </div>
                        </td>

                        <td class="px-6 py-4 text-sm text-gray-600 uppercase">
                          {document.file_type}
                        </td>

                        <td class="px-6 py-4 text-sm text-gray-600">
                          {format_file_size(document.file_size)}
                        </td>

                        <td class="px-6 py-4">
                          <span class={[
                            "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
                            status_color(document.status)
                          ]}>
                            {format_status(document.status)}
                          </span>
                        </td>

                        <td class="px-6 py-4 text-sm text-gray-600">
                          {Calendar.strftime(document.inserted_at, "%b %d, %Y")}
                        </td>

                        <td class="px-6 py-4 text-right">
                          <div class="flex justify-end gap-2">
                            <%= if document.status == "failed" do %>
                              <button
                                phx-click="reprocess_document"
                                phx-value-id={document.id}
                                class="text-blue-600 hover:text-blue-800 p-1"
                                title="Retry processing"
                              >
                                <.icon name="hero-arrow-path" class="w-4 h-4" />
                              </button>
                            <% end %>

                            <button
                              phx-click="delete_document"
                              phx-value-id={document.id}
                              data-confirm="Are you sure you want to delete this document? This action cannot be undone."
                              class="text-red-600 hover:text-red-800 p-1"
                              title="Delete document"
                            >
                              <.icon name="hero-trash" class="w-4 h-4" />
                            </button>
                          </div>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </Layouts.app_wide>
    """
  end

  defp document_icon("pdf"), do: "hero-document-text"
  defp document_icon(_), do: "hero-document"

  defp format_file_size(size) when size < 1024, do: "#{size} B"
  defp format_file_size(size) when size < 1024 * 1024, do: "#{div(size, 1024)} KB"
  defp format_file_size(size), do: "#{Float.round(size / (1024 * 1024), 1)} MB"

  defp format_status("pending"), do: "Pending"
  defp format_status("processing"), do: "Processing"
  defp format_status("processed"), do: "Ready"
  defp format_status("failed"), do: "Failed"

  defp status_color("pending"), do: "bg-yellow-100 text-yellow-800"
  defp status_color("processing"), do: "bg-blue-100 text-blue-800"
  defp status_color("processed"), do: "bg-green-100 text-green-800"
  defp status_color("failed"), do: "bg-red-100 text-red-800"

  defp error_to_string(:too_large), do: "File too large (max 50MB)"
  defp error_to_string(:too_many_files), do: "Too many files (max 5)"
  defp error_to_string(:not_accepted), do: "File type not supported"
  defp error_to_string(_), do: "Upload error"
end
