defmodule StudyBotWeb.PageController do
  use StudyBotWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
