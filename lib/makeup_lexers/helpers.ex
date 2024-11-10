defmodule MakeupLexers.Helper do
  @moduledoc false
  import NimbleParsec

  def with_optional_separator(combinator, separator) when is_binary(separator) do
    repeat(combinator, string(separator) |> concat(combinator))
  end
end
