defmodule StudyBotWeb.CoursesLive do
  use StudyBotWeb, :live_view

  alias StudyBot.Courses
  alias StudyBot.Courses.Course

  @impl true
  def mount(_params, _session, socket) do
    courses = Courses.list_courses()

    {:ok,
     socket
     |> assign(:courses, courses)
     |> assign(:page_title, "Study Bot - Course Selection")
     |> assign(:form, to_form(Course.changeset(%Course{}, %{})))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Study Bot - Course Selection")
    |> assign(:course, nil)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Course")
    |> assign(:course, %Course{})
    |> assign(:form, to_form(Course.changeset(%Course{}, %{})))
  end

  @impl true
  def handle_event("create_course", %{"course" => course_params}, socket) do
    case Courses.create_course(course_params) do
      {:ok, _course} ->
        courses = Courses.list_courses()

        {:noreply,
         socket
         |> assign(:courses, courses)
         |> assign(:form, to_form(Course.changeset(%Course{}, %{})))
         |> put_flash(:info, "Course created successfully!")
         |> push_patch(to: ~p"/")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("validate_course", %{"course" => course_params}, socket) do
    changeset =
      %Course{}
      |> Course.changeset(course_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("delete_course", %{"id" => id}, socket) do
    course = Courses.get_course!(id)
    {:ok, _} = Courses.delete_course(course)

    courses = Courses.list_courses()

    {:noreply,
     socket
     |> assign(:courses, courses)
     |> put_flash(:info, "Course deleted successfully!")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app_wide flash={@flash}>
      <div class="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100">
        <div class="container mx-auto px-6 py-8">
          <div class="text-center mb-12">
            <h1 class="text-4xl font-bold text-gray-800 mb-4">
              📚 StudyBot
            </h1>
            <p class="text-xl text-gray-600">
              Your AI-powered study assistant
            </p>
          </div>

          <div class="max-w-6xl mx-auto">
            <div class="flex justify-between items-center mb-8">
              <h2 class="text-2xl font-semibold text-gray-800">Your Courses</h2>
              <.link
                patch={~p"/courses/new"}
                class="bg-blue-600 hover:bg-blue-700 text-white px-6 py-3 rounded-lg font-medium transition-colors duration-200"
              >
                <.icon name="hero-plus" class="w-5 h-5 inline mr-2" /> New Course
              </.link>
            </div>

            <%= if @live_action == :new do %>
              <div class="bg-white rounded-xl shadow-lg p-6 mb-8">
                <h3 class="text-xl font-semibold text-gray-800 mb-6">Create New Course</h3>

                <.form
                  for={@form}
                  phx-submit="create_course"
                  phx-change="validate_course"
                  id="course-form"
                >
                  <div class="grid md:grid-cols-2 gap-6">
                    <div>
                      <.input
                        field={@form[:name]}
                        type="text"
                        label="Course Name"
                        placeholder="e.g., Introduction to Psychology"
                      />
                    </div>
                    <div>
                      <.input field={@form[:color]} type="color" label="Color" />
                    </div>
                  </div>

                  <div class="mt-6">
                    <.input
                      field={@form[:description]}
                      type="textarea"
                      label="Description (Optional)"
                      placeholder="Brief description of the course..."
                      rows="3"
                    />
                  </div>

                  <div class="flex justify-end gap-3 mt-6">
                    <.link
                      patch={~p"/"}
                      class="px-4 py-2 text-gray-600 hover:text-gray-800 font-medium"
                    >
                      Cancel
                    </.link>
                    <button
                      type="submit"
                      class="bg-blue-600 hover:bg-blue-700 text-white px-6 py-2 rounded-lg font-medium transition-colors duration-200"
                    >
                      Create Course
                    </button>
                  </div>
                </.form>
              </div>
            <% end %>

            <%= if @courses == [] do %>
              <div class="text-center py-12">
                <div class="text-6xl mb-4">📖</div>
                <h3 class="text-xl font-semibold text-gray-700 mb-2">No courses yet</h3>
                <p class="text-gray-600 mb-6">
                  Create your first course to get started with StudyBot
                </p>
                <.link
                  patch={~p"/courses/new"}
                  class="bg-blue-600 hover:bg-blue-700 text-white px-6 py-3 rounded-lg font-medium transition-colors duration-200"
                >
                  Create Your First Course
                </.link>
              </div>
            <% else %>
              <div class="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
                <%= for course <- @courses do %>
                  <div class="bg-white rounded-xl shadow-lg overflow-hidden hover:shadow-xl transition-shadow duration-200">
                    <div class="h-2" style={"background-color: #{course.color}"}></div>

                    <div class="p-6">
                      <div class="flex justify-between items-start mb-4">
                        <h3 class="text-lg font-semibold text-gray-800 line-clamp-2">
                          {course.name}
                        </h3>

                        <button
                          phx-click="delete_course"
                          phx-value-id={course.id}
                          data-confirm="Are you sure you want to delete this course? This will remove all associated documents and chat history."
                          class="text-red-500 hover:text-red-700 p-1"
                        >
                          <.icon name="hero-trash" class="w-4 h-4" />
                        </button>
                      </div>

                      <%= if course.description do %>
                        <p class="text-gray-600 text-sm mb-4 line-clamp-3">
                          {course.description}
                        </p>
                      <% end %>

                      <div class="flex justify-between items-center text-sm text-gray-500 mb-6">
                        <span>
                          {Courses.count_processed_documents(course.id)}/{Courses.count_documents(
                            course.id
                          )} documents
                        </span>
                        <span>
                          Created {Calendar.strftime(course.inserted_at, "%b %d")}
                        </span>
                      </div>

                      <div class="flex gap-2">
                        <.link
                          navigate={~p"/courses/#{course.id}"}
                          class="flex-1 bg-blue-600 hover:bg-blue-700 text-white text-center py-2 px-4 rounded-lg font-medium transition-colors duration-200"
                        >
                          <.icon name="hero-chat-bubble-left-right" class="w-4 h-4 inline mr-1" />
                          Chat
                        </.link>

                        <.link
                          navigate={~p"/courses/#{course.id}/documents"}
                          class="flex-1 bg-gray-100 hover:bg-gray-200 text-gray-700 text-center py-2 px-4 rounded-lg font-medium transition-colors duration-200"
                        >
                          <.icon name="hero-document-text" class="w-4 h-4 inline mr-1" /> Docs
                        </.link>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.app_wide>
    """
  end
end
