defmodule MakeupLexers.JavascriptLexer do
  @moduledoc """
  A `Makeup` lexer for the JavaScript language.

  This was created by putting the Pygments JavaScript lexer definition into
  an LLM next to the official ElixirLexer and then refining it manually to
  properly handle special cases like arrow functions, regexes, etc.
  """

  # helpful: https://tc39.es/ecma262/multipage/ecmascript-language-lexical-grammar.html#sec-ecmascript-language-lexical-grammar
  #
  # note that this lexer does not strictly follow the specification

  import NimbleParsec
  import Makeup.Lexer.Combinators
  import Makeup.Lexer.Groups
  import MakeupLexers.Helpers

  alias MakeupLexers.Javascript.ImportDeclaration
  alias MakeupLexers.Javascript.ExportDeclaration

  @behaviour Makeup.Lexer

  # Split builtins into categories for better organization
  @builtins_global ~w(
    window document console global globalThis process Buffer
    setTimeout setInterval clearTimeout clearInterval
    require module exports __dirname __filename
  )

  @builtins_classes ~w(
    Object Array String Number Boolean Date RegExp Function
    Promise Map Set WeakMap WeakSet Symbol BigInt Proxy Reflect JSON
    Int8Array Uint8Array Int16Array Uint16Array Int32Array Uint32Array
    Float32Array Float64Array BigInt64Array BigUint64Array
    ArrayBuffer SharedArrayBuffer DataView Math
  )

  @builtins_error ~w(
    Error EvalError RangeError ReferenceError SyntaxError TypeError URIError
    AggregateError InternalError
  )

  @builtins_methods ~w(
    parseInt parseFloat isNaN isFinite encodeURI decodeURI
    encodeURIComponent decodeURIComponent eval uneval
  )

  @builtins_special_vars ~w(
    this arguments super
  )

  @builtins @builtins_global ++
              @builtins_classes ++
              @builtins_error ++
              @builtins_methods

  ###################################################################
  # Step #1: tokenize the input (into a list of tokens)
  ###################################################################

  hashbang =
    string("#!")
    |> repeat(lookahead_not(ascii_char([?\n])) |> utf8_string([], 1))
    |> token(:comment_hashbang)

  # Whitespace and comments
  whitespace = ascii_string([?\r, ?\s, ?\n, ?\t], min: 1) |> token(:whitespace)

  newlines =
    optional(ascii_string([?\s, ?\t, ?\r], min: 1))
    |> choice([string("\r\n"), string("\n")])
    |> optional(ascii_string([?\s, ?\n, ?\f, ?\r], min: 1))
    |> token(:whitespace)

  comment_single =
    string("//")
    |> repeat(lookahead_not(ascii_char([?\n])) |> utf8_string([], 1))
    |> token(:comment_single)

  comment_multiline =
    string("/*")
    |> repeat(lookahead_not(string("*/")) |> utf8_string([], 1))
    |> string("*/")
    |> token(:comment_multiline)

  # Numbers
  digits = ascii_string([?0..?9], min: 1)
  bin_digits = ascii_string([?0..?1], min: 1)
  hex_digits = ascii_string([?0..?9, ?a..?f, ?A..?F], min: 1)
  oct_digits = ascii_string([?0..?7], min: 1)

  # Digits in an integer may be separated by underscores
  number_bin_part = with_optional_separator(bin_digits, "_")
  number_oct_part = with_optional_separator(oct_digits, "_")
  number_hex_part = with_optional_separator(hex_digits, "_")
  integer = with_optional_separator(digits, "_")

  # Tokens for the lexer
  number_bin = string("0b") |> concat(number_bin_part) |> token(:number_bin)
  number_oct = string("0o") |> concat(number_oct_part) |> token(:number_oct)
  number_hex = string("0x") |> concat(number_hex_part) |> token(:number_hex)
  # Base 10
  number_integer =
    times(integer, min: 1)
    |> optional(string("n"))
    |> token(:number_integer)

  # Floating point numbers
  float_scientific_notation_part =
    ascii_string([?e, ?E], 1)
    |> optional(string("-"))
    |> concat(integer)

  number_float =
    integer
    |> string(".")
    |> concat(integer)
    |> optional(float_scientific_notation_part)
    |> token(:number_float)

  # Regular expressions
  regex_char_escape =
    string("\\")
    |> utf8_string([], 1)

  regex_char_class =
    string("[")
    |> repeat(
      choice([
        # escaped closing bracket
        string("\\]"),
        # escaped opening bracket
        string("\\["),
        # escaped backslash
        string("\\\\"),
        # any char except ] or \
        utf8_string([not: ?], not: ?\\], 1)
      ])
    )
    |> string("]")

  regex_char =
    choice([
      regex_char_escape,
      regex_char_class,
      # escaped forward slash
      string("\\/"),
      # any char except /, \ or newline
      utf8_string([not: ?/, not: ?\\, not: ?\n], 1)
    ])

  regex_pattern =
    string("/")
    |> repeat(parsec(:regex_char))
    |> string("/")
    |> optional(ascii_string([?g, ?i, ?m, ?s, ?u, ?y], min: 1))
    |> token(:string_regex)

  # Make regex_char available as a parsec
  defparsec(:regex_char, regex_char)

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

  string_interpol = many_surrounded_by(parsec(:root_element), "${", "}", :string_interpol)
  string_double = string_like("\"", "\"", combinators_inside_string, :string_double)
  string_single = string_like("'", "'", combinators_inside_string, :string_single)

  string_template =
    string_like("`", "`", [string_interpol | combinators_inside_string], :string_backtick)

  # Variables and identifiers
  identifier_start = ascii_string([?a..?z, ?A..?Z, ?_], 1)
  identifier_part = ascii_string([?a..?z, ?A..?Z, ?0..?9, ?_], min: 0)

  identifier =
    concat(identifier_start, identifier_part)
    |> lexeme()
    |> map(:process_identifier)

  # Private field identifier
  private_field =
    string("#")
    |> concat(identifier_start)
    |> concat(optional(identifier_part))
    |> token(:name_property)

  # Process identifiers to handle keywords and builtins
  @doc false
  def process_identifier(text) do
    cond do
      # Must match exact word for keywords
      text in @builtins_special_vars -> {:name_builtin_pseudo, %{}, text}
      text in get_keywords() -> {:keyword, %{}, text}
      text in get_keyword_declarations() -> {:keyword_declaration, %{}, text}
      text in get_keyword_reserved() -> {:keyword_reserved, %{}, text}
      text in get_keyword_constants() -> {:name_constant, %{}, text}
      text in @builtins -> {:name_builtin, %{}, text}
      text in get_operator_words() -> {:operator_word, %{}, text}
      # we just assume it's a class if it starts with a capital letter
      String.match?(text, ~r/^[A-Z]/) -> {:name_class, %{}, text}
      true -> {:name, %{}, text}
    end
  end

  # Keyword lists
  defp get_keywords do
    ~w(if else for while do break return continue switch case default
       throw try catch finally yield await async with of get set static
       constructor extends implements)
  end

  defp get_keyword_declarations do
    ~w(var let const function class)
  end

  defp get_keyword_reserved do
    ~w(abstract boolean byte char double enum final float goto implements
       int interface long native package private protected public short
       synchronized throws transient volatile)
  end

  defp get_keyword_constants do
    ~w(true false null undefined NaN Infinity)
  end

  defp get_operator_words do
    ~w(typeof instanceof in void delete new)
  end

  # Operators
  operator =
    word_from_list(
      ~w(
        + - * / % ** ++ -- << >> >>> & | ^ ! ~ && || ?? ?. ?.?
        = += -= *= /= %= **= <<= >>= >>>= &= |= ^= &&= ||= ??=
        == === != !== < <= > >= ? :
      ),
      :operator
    )

  # Punctuation
  punctuation = word_from_list(~w(\( \) [ ] { } . , ;), :punctuation)

  object = many_surrounded_by(parsec(:root_element), "{", "}", :punctuation)
  array = many_surrounded_by(parsec(:root_element), "[", "]", :punctuation)
  block = many_surrounded_by(parsec(:root_element), "{", "}", :punctuation)

  # Arrow function needs to be before the operator combinator
  arrow = string("=>") |> token(:punctuation)

  # Error fallback
  any_char = utf8_char([]) |> token(:error)

  # The main parsing logic
  root_element_combinator =
    choice([
      hashbang,
      whitespace,
      newlines,
      comment_single,
      comment_multiline,
      regex_pattern,
      private_field,
      number_float,
      number_hex,
      number_bin,
      number_oct,
      number_integer,
      string_double,
      string_single,
      string_template,
      string_interpol,
      arrow,
      operator,
      object,
      array,
      block,
      punctuation,
      parsec({ImportDeclaration, :import_declaration}),
      parsec({ExportDeclaration, :export_declaration}),
      identifier,
      any_char
    ])

  # By default, don't inline the lexers.
  # Inlining them increases performance by ~20%
  # at the cost of doubling the compilation times...
  @inline false

  # Semi-public API: these two functions can be used by someone who wants to
  # embed a JavaScript lexer into another lexer, but other than that, they are not
  # meant to be used by end-users.

  # Parse a single root element
  defparsec(
    :root_element,
    root_element_combinator |> map({__MODULE__, :__as_javascript_language__, []}),
    inline: @inline,
    export_combinator: true
  )

  # Parse the complete input
  defparsec(
    :root,
    repeat(parsec(:root_element)),
    inline: @inline,
    export_combinator: true
  )

  ###################################################################
  # Step #2: postprocess the list of tokens
  ###################################################################

  # Enhanced postprocessing for function calls and property access
  defp postprocess_helper([]), do: []

  # Handle class method definitions
  defp postprocess_helper([
         {name_type, attrs1, class_name},
         {:punctuation, _, "."},
         {:name, attrs2, "prototype"},
         {:punctuation, _, "."},
         {:name, attrs3, method_name} | rest
       ])
       when name_type in [:name, :name_builtin] do
    [
      {name_type, attrs1, class_name},
      {:punctuation, %{language: :javascript}, "."},
      {:name, attrs2, "prototype"},
      {:punctuation, %{language: :javascript}, "."},
      {:name_function, attrs3, method_name} | postprocess_helper(rest)
    ]
  end

  # Handle method calls
  defp postprocess_helper([
         {name_type, attrs1, obj},
         {:punctuation, _, "."},
         {:name, attrs2, prop},
         {:punctuation, _, "("} | rest
       ])
       when name_type in [:name, :name_builtin] do
    [
      {name_type, attrs1, obj},
      {:punctuation, %{language: :javascript}, "."},
      {:name_function, attrs2, prop},
      {:punctuation, %{language: :javascript}, "("} | postprocess_helper(rest)
    ]
  end

  # Handle property access
  defp postprocess_helper([
         {name_type, attrs1, obj},
         {:punctuation, _, "."},
         {:name, attrs2, prop} | rest
       ])
       when name_type in [:name, :name_builtin] do
    [
      {name_type, attrs1, obj},
      {:punctuation, %{language: :javascript}, "."},
      {:name, attrs2, prop} | postprocess_helper(rest)
    ]
  end

  # Handle function calls
  defp postprocess_helper([
         {:name, attrs, name},
         {:punctuation, _, "("} | rest
       ]) do
    [
      {:name_function, attrs, name},
      {:punctuation, %{language: :javascript}, "("} | postprocess_helper(rest)
    ]
  end

  # Handle function declarations
  defp postprocess_helper([
         {:keyword_declaration, attrs1, "function"},
         {:whitespace, _, _} = ws,
         {:name, attrs2, name} | rest
       ]) do
    [
      {:keyword_declaration, attrs1, "function"},
      ws,
      {:name_function, attrs2, name} | postprocess_helper(rest)
    ]
  end

  # Handle get/set in object literals
  defp postprocess_helper([
         {:keyword, attrs, keyword},
         {:whitespace, _, _} = ws,
         {:name, name_attrs, name} | rest
       ])
       when keyword in ["get", "set"] do
    [
      {:keyword, attrs, keyword},
      ws,
      {:name_function, name_attrs, name} | postprocess_helper(rest)
    ]
  end

  # Handle keywords that become methods when accessed with dot notation
  defp postprocess_helper([
         {:punctuation, _, "."},
         {:keyword, attrs, method} | rest
       ]) do
    [
      {:punctuation, %{language: :javascript}, "."},
      {:name_function, attrs, method} | postprocess_helper(rest)
    ]
  end

  # Handle no-parameter arrow function
  defp postprocess_helper([
         {:name, attrs, name},
         {:whitespace, _, _} = ws1,
         {:operator, _, "="},
         {:whitespace, _, _} = ws2,
         {:punctuation, _, "("},
         {:punctuation, _, ")"},
         {:whitespace, _, _} = ws3,
         {:punctuation, _, "=>"} | rest
       ]) do
    [
      {:name_function, attrs, name},
      ws1,
      {:operator, %{language: :javascript}, "="},
      ws2,
      {:punctuation, %{language: :javascript}, "("},
      {:punctuation, %{language: :javascript}, ")"},
      ws3,
      {:punctuation, %{language: :javascript}, "=>"}
      | postprocess_helper(rest)
    ]
  end

  # Handle arrow function with parentheses and multiple parameters
  defp postprocess_helper([
         {:name, attrs, name},
         {:whitespace, _, _} = ws1,
         {:operator, _, "="},
         {:whitespace, _, _} = ws2,
         {:punctuation, _, "("} | rest
       ]) do
    case find_arrow_function(rest) do
      {:ok, acc, rest} ->
        [
          {:name_function, attrs, name},
          ws1,
          {:operator, %{language: :javascript}, "="},
          ws2,
          {:punctuation, %{language: :javascript}, "("}
          | postprocess_helper(acc ++ rest)
        ]

      :error ->
        [
          {:name, attrs, name},
          ws1,
          {:operator, %{language: :javascript}, "="},
          ws2,
          {:punctuation, %{language: :javascript}, "("}
          | postprocess_helper(rest)
        ]
    end
  end

  # Handle single parameter arrow function without parentheses
  defp postprocess_helper([
         {:name, attrs, name},
         {:whitespace, _, _} = ws1,
         {:operator, _, "="},
         {:whitespace, _, _} = ws2,
         {:name, param_attrs, param_name},
         {:whitespace, _, _} = ws3,
         {:punctuation, _, "=>"} | rest
       ]) do
    [
      {:name_function, attrs, name},
      ws1,
      {:operator, %{language: :javascript}, "="},
      ws2,
      {:name, param_attrs, param_name},
      ws3,
      {:punctuation, %{language: :javascript}, "=>"}
      | postprocess_helper(rest)
    ]
  end

  # don't highlight something like const float = 1.0
  defp postprocess_helper([
         {:keyword_declaration, _, _} = declaration,
         {:whitespace, _, _} = ws,
         {ttype, attrs, name} | rest
       ])
       when ttype in [:keyword_reserved, :keyword] do
    [
      declaration,
      ws,
      {:name, attrs, name}
      | postprocess_helper(rest)
    ]
  end

  defp postprocess_helper([token | rest]), do: [token | postprocess_helper(rest)]

  # Helper function to find arrow function pattern in token stream
  defp find_arrow_function(tokens, acc \\ [])

  defp find_arrow_function([], _acc), do: :error

  defp find_arrow_function(
         [
           {:punctuation, _, ")"},
           ws = {:whitespace, _, _},
           {:punctuation, _, "=>"} | rest
         ],
         acc
       ) do
    {:ok,
     Enum.reverse(acc) ++
       [
         {:punctuation, %{language: :javascript}, ")"},
         ws,
         {:punctuation, %{language: :javascript}, "=>"}
       ], rest}
  end

  defp find_arrow_function([token | rest], acc) do
    find_arrow_function(rest, [token | acc])
  end

  # Add language tag
  def __as_javascript_language__({ttype, meta, value}) do
    {ttype, Map.put(meta, :language, :javascript), value}
  end

  @impl Makeup.Lexer
  def postprocess(tokens, _opts \\ []), do: postprocess_helper(tokens)

  # Match groups for paired delimiters
  @impl Makeup.Lexer
  defgroupmatcher(:match_groups,
    parentheses: [
      open: [[{:punctuation, %{language: :javascript}, "("}]],
      close: [[{:punctuation, %{language: :javascript}, ")"}]]
    ],
    brackets: [
      open: [[{:punctuation, %{language: :javascript}, "["}]],
      close: [[{:punctuation, %{language: :javascript}, "]"}]]
    ],
    braces: [
      open: [[{:punctuation, %{language: :javascript}, "{"}]],
      close: [[{:punctuation, %{language: :javascript}, "}"}]]
    ],
    template_interpolation: [
      open: [[{:string_interpol, %{language: :javascript}, "${"}]],
      close: [[{:string_interpol, %{language: :javascript}, "}"}]]
    ]
  )

  # Public lexing API
  @impl Makeup.Lexer
  def lex(text, opts \\ []) do
    group_prefix = Keyword.get(opts, :group_prefix, random_prefix(10))

    {:ok, tokens, "", _, _, _} = root(text)

    tokens
    |> postprocess([])
    |> match_groups(group_prefix)
  end
end
