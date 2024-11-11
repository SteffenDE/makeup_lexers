defmodule MakeupLexers.Application do
  @moduledoc false
  use Application

  alias Makeup.Registry

  def start(_type, _args) do
    Registry.register_lexer(MakeupLexers.JavascriptLexer,
      options: [],
      names: ["javascript"],
      extensions: ["js"]
    )

    Registry.register_lexer(MakeupLexers.XMLLexer,
      options: [],
      names: ["xml"],
      extensions: ["xml"]
    )

    Registry.register_lexer(MakeupLexers.HTMLLexer,
      options: [],
      names: ["html"],
      extensions: ["html"]
    )

    Supervisor.start_link([], strategy: :one_for_one)
  end
end
