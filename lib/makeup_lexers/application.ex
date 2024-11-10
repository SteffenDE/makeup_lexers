defmodule MakeupLexers.Application do
  @moduledoc false
  use Application

  alias Makeup.Registry
  alias Makeup.Lexers.JavascriptLexer

  def start(_type, _args) do
    Registry.register_lexer(JavascriptLexer,
      options: [],
      names: ["javascript"],
      extensions: ["js"]
    )

    Supervisor.start_link([], strategy: :one_for_one)
  end
end
