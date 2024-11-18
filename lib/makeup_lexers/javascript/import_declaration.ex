defmodule MakeupLexers.Javascript.ImportDeclaration do
  import NimbleParsec
  import Makeup.Lexer.Combinators

  alias MakeupLexers.Javascript.ImportAttributes

  # https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Statements/import
  # https://tc39.es/ecma262/multipage/ecmascript-language-scripts-and-modules.html#sec-imports

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

  module_specifier =
    choice([
      string_double,
      string_single
    ])

  binding_identifier =
    identifier_start
    |> concat(identifier_part)
    |> lexeme()
    |> map({MakeupLexers.JavascriptLexer, :process_identifier, []})

  imported_binding = binding_identifier

  module_export_name =
    choice([
      token(string("default"), :keyword_namespace),
      binding_identifier,
      string_double,
      string_single
    ])

  import_specifier =
    choice([
      # ModuleExportName as ImportedBinding
      module_export_name
      |> concat(whitespace)
      |> concat(string("as") |> token(:keyword_namespace))
      |> concat(whitespace)
      |> concat(imported_binding),
      # ImportedBinding
      imported_binding
    ])

  imports_list =
    repeat(
      import_specifier
      |> optional(
        optional_ws
        |> string(",")
        |> token(:punctuation)
        |> concat(optional_ws)
      )
    )

  named_imports =
    string("{")
    |> token(:punctuation)
    |> concat(optional_ws)
    |> concat(imports_list)
    |> concat(optional_ws)
    |> concat(string("}") |> token(:punctuation))

  namespace_import =
    string("*")
    |> token(:operator)
    |> concat(whitespace)
    |> concat(string("as") |> token(:keyword_namespace))
    |> concat(whitespace)
    |> concat(imported_binding)

  imported_default_binding = imported_binding

  import_clause =
    choice([
      # ImportedDefaultBinding , NameSpaceImport
      imported_default_binding
      |> concat(optional_ws)
      |> concat(string(",") |> token(:punctuation))
      |> concat(optional_ws)
      |> concat(namespace_import),
      # ImportedDefaultBinding , NamedImports
      imported_default_binding
      |> concat(optional_ws)
      |> concat(string(",") |> token(:punctuation))
      |> concat(optional_ws)
      |> concat(named_imports),
      # ImportedDefaultBinding
      imported_default_binding,
      # NameSpaceImport
      namespace_import,
      # NamedImports
      named_imports
    ])

  from_clause =
    whitespace
    |> concat(string("from") |> token(:keyword_namespace))
    |> concat(whitespace)
    |> concat(module_specifier)

  import_declaration =
    string("import")
    |> token(:keyword_namespace)
    |> choice([
      # import ImportClause FromClause WithClause? ;
      whitespace
      |> concat(import_clause)
      |> concat(from_clause)
      |> concat(optional_ws)
      |> concat(optional(parsec({ImportAttributes, :with_clause})))
      |> concat(optional_ws)
      |> concat(optional(string(";") |> token(:punctuation))),
      # import ModuleSpecifier WithClause? ;
      whitespace
      |> concat(module_specifier)
      |> concat(optional_ws)
      |> concat(optional(parsec({ImportAttributes, :with_clause})))
      |> concat(optional_ws)
      |> concat(optional(string(";") |> token(:punctuation)))
    ])

  defcombinator(:import_declaration, import_declaration)
end
