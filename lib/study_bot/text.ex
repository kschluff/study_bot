defmodule StudyBot.Text do
  @moduledoc false
  require Logger

  @doc """
  Ensures binaries are valid UTF-8, attempting conversion from Latin-1 and
  falling back to replacement characters when necessary.
  """
  def sanitize(content) when is_binary(content) do
    content
    |> replace_invalid()
  end

  def sanitize(content), do: content

  defp replace_invalid(content) do
    case String.split(content, <<0x9A>> <> <<0xA0>>, parts: 2) do
      [before, rest | _] ->
        Logger.warning("Replacing 0x9A sequence in content")
        replace_invalid(before <> " ") <> replace_invalid(rest)

      _ ->
        if String.valid?(content) do
          content
        else
          Logger.warning("Invalid UTF-8 detected", content: Base.encode16(content, case: :lower))
          String.replace_invalid(content, "?")
        end
    end
  end
end
