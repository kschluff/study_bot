defmodule StudyBotWeb.HealthController do
  use StudyBotWeb, :controller

  def index(conn, _params) do
    send_resp(conn, :no_content, "")
  end
end
