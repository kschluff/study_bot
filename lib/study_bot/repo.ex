defmodule StudyBot.Repo do
  use Ecto.Repo,
    otp_app: :study_bot,
    adapter: Ecto.Adapters.SQLite3
end
