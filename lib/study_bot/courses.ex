defmodule StudyBot.Courses do
  @moduledoc """
  The Courses context manages course entities and related operations.
  """

  import Ecto.Query, warn: false
  alias StudyBot.Repo
  alias StudyBot.Courses.Course

  def list_courses do
    Repo.all(from c in Course, where: c.active == true, order_by: [asc: c.name])
  end

  def list_all_courses do
    Repo.all(from c in Course, order_by: [asc: c.name])
  end

  def get_course!(id), do: Repo.get!(Course, id)

  def get_course(id), do: Repo.get(Course, id)

  def get_course_by_name(name) do
    Repo.get_by(Course, name: name)
  end

  def create_course(attrs \\ %{}) do
    %Course{}
    |> Course.changeset(attrs)
    |> Repo.insert()
  end

  def update_course(%Course{} = course, attrs) do
    course
    |> Course.changeset(attrs)
    |> Repo.update()
  end

  def delete_course(%Course{} = course) do
    Repo.delete(course)
  end

  def change_course(%Course{} = course, attrs \\ %{}) do
    Course.changeset(course, attrs)
  end

  def activate_course(%Course{} = course) do
    update_course(course, %{active: true})
  end

  def deactivate_course(%Course{} = course) do
    update_course(course, %{active: false})
  end

  def count_documents(course_id) do
    from(d in StudyBot.Documents.Document, where: d.course_id == ^course_id)
    |> Repo.aggregate(:count, :id)
  end

  def count_processed_documents(course_id) do
    from(d in StudyBot.Documents.Document,
      where: d.course_id == ^course_id and d.status == "processed"
    )
    |> Repo.aggregate(:count, :id)
  end
end
