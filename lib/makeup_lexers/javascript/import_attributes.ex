defmodule MakeupLexers.Javascript.ImportAttributes do
  import NimbleParsec
  import Makeup.Lexer.Combinators

  # https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Statements/import/with
  # https://tc39.es/proposal-import-attributes/#prod-WithClause

  # Whitespace and comments
  whitespace = ascii_string([?\r, ?\s, ?\n, ?\t], min: 1) |> token(:whitespace)
  optional_ws = optional(whitespace)

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

  identifier =
    identifier_start
    |> concat(identifier_part)
    |> lexeme()
    |> map({MakeupLexers.JavascriptLexer, :process_identifier, []})

  # With clause combinators
  attribute_key =
    choice([
      identifier,
      string_double,
      string_single
    ])

  with_entries =
    attribute_key
    |> concat(optional_ws)
    |> concat(string(":") |> token(:punctuation))
    |> concat(optional_ws)
    |> concat(
      choice([
        string_double,
        string_single
      ])
    )
    |> repeat(
      optional_ws
      |> concat(string(",") |> token(:punctuation))
      |> concat(optional_ws)
      |> concat(attribute_key)
      |> concat(optional_ws)
      |> concat(string(":") |> token(:punctuation))
      |> concat(optional_ws)
      |> concat(
        choice([
          string_double,
          string_single
        ])
      )
    )

  with_clause =
    string("with")
    |> token(:keyword_namespace)
    |> concat(optional_ws)
    |> concat(string("{") |> token(:punctuation))
    |> concat(optional_ws)
    |> optional(with_entries)
    |> concat(optional_ws)
    |> concat(string("}") |> token(:punctuation))

  defcombinator(:with_clause, with_clause)
end
