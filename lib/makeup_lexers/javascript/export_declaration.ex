defmodule MakeupLexers.Javascript.ExportDeclaration do
  import NimbleParsec
  import Makeup.Lexer.Combinators

  alias MakeupLexers.JavascriptLexer
  alias MakeupLexers.Javascript.ImportAttributes

  # https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Statements/export

  # Strings
  string_escape = string("\\") |> utf8_string([], 1) |> token(:string_escape)

  unicode_char_in_string =
    string("\\u")
    |> ascii_string([?0..?9, ?a..?f, ?A..?F], 4)
    |> token(:string_escape)

  combinators_inside_string = [
    unicode_char_in_string,
    string_escape
  ]

  string_double = string_like("\"", "\"", combinators_inside_string, :string_double)
  string_single = string_like("'", "'", combinators_inside_string, :string_single)

  # Variables and identifiers
  identifier_start = ascii_string([?a..?z, ?A..?Z, ?_], 1)
  identifier_part = ascii_string([?a..?z, ?A..?Z, ?0..?9, ?_], min: 0)

  module_specifier =
    choice([
      string_double,
      string_single
    ])

  # Export statement combinators based on ECMAScript spec
  export_ws = ascii_string([?\s, ?\n, ?\r, ?\t], min: 1) |> token(:whitespace)
  optional_ws = optional(export_ws)

  binding_identifier =
    identifier_start
    |> concat(identifier_part)
    |> lexeme()
    |> map({MakeupLexers.JavascriptLexer, :process_identifier, []})

  module_export_name =
    choice([
      token(string("default"), :keyword_namespace),
      binding_identifier,
      string_double,
      string_single
    ])

  export_specifier =
    choice([
      # ModuleExportName as ModuleExportName
      module_export_name
      |> concat(export_ws)
      |> concat(string("as") |> token(:keyword_namespace))
      |> concat(export_ws)
      |> concat(module_export_name),
      # ModuleExportName
      module_export_name
    ])

  exports_list =
    repeat(
      export_specifier
      |> optional(
        optional_ws
        |> string(",")
        |> token(:punctuation)
        |> concat(optional_ws)
      )
    )

  named_exports =
    string("{")
    |> token(:punctuation)
    |> concat(optional_ws)
    |> concat(exports_list)
    |> concat(optional_ws)
    |> concat(
      string("}")
      |> token(:punctuation)
    )

  export_from_clause =
    choice([
      # * as ModuleExportName
      string("*")
      |> token(:operator)
      |> concat(export_ws)
      |> concat(string("as") |> token(:keyword_namespace))
      |> concat(export_ws)
      |> concat(module_export_name),
      # *
      string("*") |> token(:operator),
      # NamedExports
      named_exports
    ])

  # Variable and function declarations are handled by looking ahead
  # to avoid ambiguity with other expressions
  declaration_start =
    lookahead(
      choice([
        string("function"),
        string("class"),
        string("async"),
        string("var"),
        string("let"),
        string("const")
      ])
    )

  export_declaration =
    string("export")
    |> token(:keyword_namespace)
    |> concat(export_ws)
    |> choice([
      # export ExportFromClause FromClause WithClause? ;
      export_from_clause
      |> concat(export_ws)
      |> concat(string("from") |> token(:keyword_namespace))
      |> concat(export_ws)
      |> concat(module_specifier)
      |> concat(optional_ws)
      |> concat(optional(parsec({ImportAttributes, :with_clause})))
      |> concat(optional_ws)
      |> concat(optional(string(";") |> token(:punctuation))),

      # export NamedExports WithClause? ;
      named_exports
      |> concat(optional_ws)
      |> concat(optional(parsec({ImportAttributes, :with_clause})))
      |> concat(optional_ws)
      |> concat(optional(string(";") |> token(:punctuation))),

      # export default ... (various forms)
      string("default")
      |> token(:keyword_namespace)
      |> concat(export_ws)
      |> concat(parsec({JavascriptLexer, :root_element})),

      # export Declaration (includes VariableStatement)
      declaration_start |> concat(parsec({JavascriptLexer, :root_element}))
    ])

  defcombinator(:export_declaration, export_declaration)
end
