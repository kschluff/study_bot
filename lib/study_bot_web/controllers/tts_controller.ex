defmodule StudyBotWeb.TTSController do
  use StudyBotWeb, :controller

  alias StudyBot.AI.Client

  require Logger

  def generate(conn, %{"text" => text} = params) do
    # Limit text length for safety and cost
    text = String.slice(text, 0, 4000)

    voice = Map.get(params, "voice", "alloy")
    speed = Map.get(params, "speed", "1.0") |> String.to_float()

    case Client.text_to_speech(text, %{voice: voice, speed: speed}) do
      {:ok, audio_data} ->
        conn
        |> put_resp_content_type("audio/mpeg")
        |> put_resp_header("cache-control", "public, max-age=3600")
        |> send_resp(200, audio_data)

      {:error, reason} ->
        Logger.error("TTS generation failed: #{reason}")

        conn
        |> put_status(500)
        |> json(%{error: "Failed to generate speech"})
    end
  end

  def generate(conn, _params) do
    conn
    |> put_status(400)
    |> json(%{error: "Missing text parameter"})
  end
end
