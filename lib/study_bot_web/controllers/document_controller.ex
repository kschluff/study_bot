defmodule StudyBotWeb.DocumentController do
  use StudyBotWeb, :controller

  alias StudyBot.Documents

  def download(conn, %{"course_id" => _course_id, "id" => id}) do
    case Documents.get_document(id) do
      %Documents.Document{} = document when document.status == "processed" ->
        conn
        |> put_resp_content_type("text/plain")
        |> put_resp_header("content-disposition", 
           "attachment; filename=\"#{document.original_filename}\"")
        |> send_resp(200, document.content || "")

      %Documents.Document{} = document ->
        conn
        |> put_flash(:error, "Document not ready for download")
        |> redirect(to: ~p"/courses/#{document.course_id}/documents")

      nil ->
        conn
        |> put_flash(:error, "Document not found")
        |> redirect(to: ~p"/")
    end
  end
end