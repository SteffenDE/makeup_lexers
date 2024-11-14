defmodule MakeupLexers.CSSLexer do
  @moduledoc """
  A `Makeup` lexer for CSS using standard Pygments token types.
  """

  import NimbleParsec
  import Makeup.Lexer.Combinators
  import Makeup.Lexer.Groups

  @behaviour Makeup.Lexer

  # Import builtins
  alias MakeupLexers.CSS.Builtins

  # CSS Units grouped by type
  @length_units ~w(em ex ch rem vw vh vmin vmax px mm cm in pt pc fr)
  @angle_units ~w(deg grad rad turn)
  @time_units ~w(s ms)
  @frequency_units ~w(Hz kHz)
  @resolution_units ~w(dpi dpcm dppx)
  @percentage ~w(%)

  @units @length_units ++
           @angle_units ++
           @time_units ++
           @frequency_units ++
           @resolution_units ++ @percentage

  # Create unit matcher
  unit_suffix =
    choice(Enum.map(@units, &string/1))

  @attr_operators ~w(= ~= |= ^= $= *=)

  # Cache built-in lists
  @properties MapSet.new(Builtins.properties())
  @colors MapSet.new(Builtins.color_keywords())
  @keyword_values MapSet.new(Builtins.keyword_values())
  @functions MapSet.new(Builtins.function_keywords())

  ###################################################################
  # Step #1: tokenize the input
  ###################################################################

  whitespace = ascii_string([?\r, ?\s, ?\n, ?\t], min: 1) |> token(:whitespace)

  comment_multiline =
    string("/*")
    |> repeat(lookahead_not(string("*/")) |> utf8_string([], 1))
    |> string("*/")
    |> token(:comment_multiline)

  # Numbers
  digits = ascii_string([?0..?9], min: 1)
  integer = concat(optional(string("-")), digits)

  float_scientific_notation_part =
    ascii_string([?e, ?E], 1)
    |> optional(string("-"))
    |> concat(digits)

  float =
    integer
    |> string(".")
    |> concat(digits)
    |> optional(float_scientific_notation_part)

  # Split number and unit into separate tokens
  number_with_unit =
    choice([float, integer])
    |> concat(unit_suffix)
    |> token(:number)

  number =
    choice([float, integer])
    |> token(:number)

  # Colors
  hex_color =
    string("#")
    |> ascii_string([?0..?9, ?a..?f, ?A..?F], min: 1)
    |> token(:string_symbol)

  # Strings
  string_escape = string("\\") |> utf8_string([], 1) |> token(:string_escape)
  string_single = string_like("'", "'", [string_escape], :string_single)
  string_double = string_like("\"", "\"", [string_escape], :string_double)

  # CSS Variables
  css_variable =
    string("--")
    |> ascii_string([?a..?z, ?A..?Z, ?0..?9, ?-, ?_], min: 1)
    |> token(:name_variable)

  var_function =
    token(string("var"), :name_function)
    |> concat(token(string("("), :punctuation))
    |> concat(
      string("--")
      |> ascii_string([?a..?z, ?A..?Z, ?0..?9, ?-, ?_], min: 1)
      |> token(:name_variable)
    )

  # Identifiers
  identifier_start = ascii_string([?a..?z, ?A..?Z, ?_], 1)
  identifier_part = ascii_string([?a..?z, ?A..?Z, ?0..?9, ?-, ?_], min: 0)

  vendor_prefixed_identifier =
    string("-")
    |> concat(identifier_start)
    |> concat(identifier_part)
    |> lexeme()
    |> map(:process_identifier)

  at_rule =
    string("@")
    |> concat(identifier_start)
    |> concat(identifier_part)
    |> lexeme()
    |> token(:keyword_declaration)

  identifier =
    concat(identifier_start, identifier_part)
    |> lexeme()
    |> map(:process_identifier)

  # Selectors
  class_selector =
    string(".")
    |> concat(identifier_start)
    |> concat(identifier_part)
    |> lexeme()
    |> token(:name_class)

  id_selector =
    string("#")
    |> concat(identifier_start)
    |> concat(identifier_part)
    |> lexeme()
    |> token(:name_label)

  pseudo_selector =
    choice([string("::"), string(":")])
    |> concat(identifier_start)
    |> concat(identifier_part)
    |> lexeme()
    |> token(:name_decorator)

  # Attribute selectors
  attribute_operator =
    word_from_list(@attr_operators, :operator)

  attribute_selector_content =
    choice([
      identifier
      |> optional(whitespace)
      |> concat(attribute_operator)
      |> optional(whitespace)
      |> concat(choice([string_single, string_double, identifier])),
      identifier
    ])

  attribute_selector =
    token(string("["), :punctuation)
    |> concat(optional(whitespace))
    |> concat(attribute_selector_content)
    |> concat(optional(whitespace))
    |> concat(token(string("]"), :punctuation))

  # Functions
  function_name =
    identifier_start
    |> concat(identifier_part)
    |> lexeme()
    |> token(:name_function)
    |> concat(token(string("("), :punctuation))

  # Operators and punctuation
  operator = word_from_list(~w(+ > ~ - * | & /), :operator)
  punctuation = word_from_list(~w({ } \( \) [ ] ; : , .), :punctuation)

  # Error fallback
  any_char = utf8_char([]) |> token(:error)

  def process_identifier(text) do
    cond do
      text in @properties -> {:name_builtin, %{}, text}
      text in @colors -> {:name_constant, %{}, text}
      text in @keyword_values -> {:name_builtin_pseudo, %{}, text}
      text in ["import", "charset", "namespace"] -> {:keyword_namespace, %{}, text}
      text in ["from", "to", "through"] -> {:keyword, %{}, text}
      text in ["and", "or", "not", "only"] -> {:operator_word, %{}, text}
      String.starts_with?(text, "@") -> {:keyword_declaration, %{}, text}
      true -> {:name, %{}, text}
    end
  end

  def process_function(text) do
    base = String.trim_trailing(text, "(")

    if base in @functions do
      {:name_function, %{}, text}
    else
      {:name_function, %{}, text}
    end
  end

  root_element_combinator =
    choice([
      whitespace,
      comment_multiline,
      hex_color,
      number_with_unit,
      number,
      string_single,
      string_double,
      css_variable,
      var_function,
      class_selector,
      id_selector,
      pseudo_selector,
      attribute_selector,
      function_name,
      identifier,
      vendor_prefixed_identifier,
      operator,
      punctuation,
      at_rule,
      any_char
    ])

  @inline false

  defparsec(
    :root_element,
    root_element_combinator |> map({__MODULE__, :__as_css_language__, []}),
    inline: @inline,
    export_combinator: true
  )

  defparsec(
    :root,
    repeat(parsec(:root_element)),
    inline: @inline,
    export_combinator: true
  )

  ###################################################################
  # Step #2: postprocess the list of tokens
  ###################################################################

  defp postprocess_helper([]), do: []

  defp postprocess_helper([
         {:name, attrs, property},
         {:punctuation, _, ":"} | rest
       ]) do
    [
      {:name_property, attrs, property},
      {:punctuation, %{language: :css}, ":"} | postprocess_helper(rest)
    ]
  end

  defp postprocess_helper([
         {:name_builtin, attrs, property},
         {:punctuation, _, ":"} | rest
       ]) do
    [
      {:name_builtin, attrs, property},
      {:punctuation, %{language: :css}, ":"} | postprocess_helper(rest)
    ]
  end

  defp postprocess_helper([token | rest]), do: [token | postprocess_helper(rest)]

  def __as_css_language__({ttype, meta, value}) do
    {ttype, Map.put(meta, :language, :css), value}
  end

  @impl Makeup.Lexer
  def postprocess(tokens, _opts \\ []), do: postprocess_helper(tokens)

  @impl Makeup.Lexer
  defgroupmatcher(:match_groups,
    braces: [
      open: [[{:punctuation, %{language: :css}, "{"}]],
      close: [[{:punctuation, %{language: :css}, "}"}]]
    ],
    parentheses: [
      open: [[{:punctuation, %{language: :css}, "("}]],
      close: [[{:punctuation, %{language: :css}, ")"}]]
    ],
    brackets: [
      open: [[{:punctuation, %{language: :css}, "["}]],
      close: [[{:punctuation, %{language: :css}, "]"}]]
    ]
  )

  @impl Makeup.Lexer
  def lex(text, opts \\ []) do
    group_prefix = Keyword.get(opts, :group_prefix, random_prefix(10))

    {:ok, tokens, "", _, _, _} = root(text)

    tokens
    |> postprocess([])
    |> match_groups(group_prefix)
  end
end
