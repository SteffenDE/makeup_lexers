defmodule MakeupLexers.Application do
  @moduledoc false
  use Application

  alias Makeup.Registry

  def start(_type, _args) do
    Registry.register_lexer(MakeupLexers.JavascriptLexer,
      options: [],
      names: ["javascript", "js"],
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

    Registry.register_lexer(MakeupLexers.CSSLexer,
      options: [],
      names: ["css"],
      extensions: ["css"]
    )

    if Code.ensure_loaded?(Makeup.Lexers.HEExLexer) do
      Registry.register_lexer(Makeup.Lexers.HEExLexer,
        options: [outer_lexer: MakeupLexers.HTMLLexer],
        names: ["heex"],
        extensions: ["heex"]
      )
    end

    if Code.ensure_loaded?(Makeup.Lexers.ElixirLexer) and
         Code.ensure_loaded?(Makeup.Lexers.HEExLexer) do
      Makeup.Lexers.ElixirLexer.register_sigil_lexer("H", Makeup.Lexers.HEExLexer,
        outer_lexer: MakeupLexers.HTMLLexer
      )
    end

    Supervisor.start_link([], strategy: :one_for_one)
  end
end
