defmodule MakeupLexers.XMLLexer do
  @moduledoc """
  A `Makeup` lexer for XML (eXtensible Markup Language).
  """

  import NimbleParsec
  import Makeup.Lexer.Combinators
  import Makeup.Lexer.Groups

  @behaviour Makeup.Lexer

  ###################################################################
  # Step #1: tokenize the input (into a list of tokens)
  ###################################################################

  whitespace = ascii_string([?\r, ?\s, ?\n, ?\t], min: 1) |> token(:whitespace)

  # Basic XML name, following W3C spec for valid tag/attribute names
  # we also allow tags starting with . (HEEx)
  xml_name =
    ascii_string([?a..?z, ?A..?Z, ?_, ?:, ?.], 1)
    |> concat(ascii_string([?a..?z, ?A..?Z, ?0..?9, ?_, ?:, ?., ?-], min: 0))
    |> lexeme()

  # Entity references like &amp; &lt; etc.
  entity =
    string("&")
    |> ascii_string([not: ?\s, not: ?;], min: 1)
    |> string(";")
    |> token(:name_entity)

  # CDATA sections
  cdata =
    string("<![CDATA[")
    |> repeat(lookahead_not(string("]]>")) |> utf8_char([]))
    |> concat(string("]]>"))
    |> lexeme()
    |> token(:comment_preproc)

  # XML comments
  comment =
    string("<!--")
    |> repeat(lookahead_not(string("-->")) |> utf8_char([]))
    |> concat(string("-->"))
    |> lexeme()
    |> token(:comment_multiline)

  # Processing instructions like <?xml version="1.0"?>
  processing_instruction =
    string("<?")
    |> repeat(lookahead_not(string("?>")) |> utf8_char([]))
    |> concat(string("?>"))
    |> lexeme()
    |> token(:comment_preproc)

  # Attribute values in single or double quotes
  attribute_value_double =
    token(string("\""), :string)
    |> concat(
      repeat(lookahead_not(string("\"")) |> utf8_char([]))
      |> lexeme()
      |> token(:string)
    )
    |> concat(token(string("\""), :string))

  attribute_value_single =
    token(string("'"), :string)
    |> concat(
      repeat(lookahead_not(string("'")) |> utf8_char([]))
      |> lexeme()
      |> token(:string)
    )
    |> concat(token(string("'"), :string))

  attribute_value =
    choice([
      attribute_value_double,
      attribute_value_single
    ])

  attribute_value_permissive =
    choice([
      attribute_value,
      # HTML5 also allows <input type=text> without quotes;
      # so while it would not be valid XML, we still allow it here
      token(utf8_string([not: ?\s, not: ?>], min: 1), :string)
    ])

  declaration =
    token(string("<"), :punctuation)
    |> concat(token(string("!"), :keyword))
    |> concat(token(xml_name, :keyword))
    |> concat(
      repeat(lookahead_not(string(">")) |> utf8_char([]))
      |> lexeme()
      |> token(:text)
    )
    |> concat(token(string(">"), :punctuation))

  # Attribute name-value pairs
  attribute =
    ascii_string([?a..?z, ?A..?Z, ?_, ?:], 1)
    |> concat(ascii_string([?a..?z, ?A..?Z, ?0..?9, ?_, ?:, ?., ?-], min: 0))
    |> lexeme()
    |> token(:name_attribute)
    |> concat(
      # while XML always requires a value, we allow empty values
      # as we reuse this lexer for HTML, where attributes without values are valid
      optional(
        optional(whitespace)
        |> concat(token(string("="), :operator))
        |> concat(
          choice([
            whitespace |> concat(attribute_value),
            attribute_value_permissive,
            empty()
          ])
        )
      )
    )

  # Doctype declarations
  doctype_inner =
    many_surrounded_by(
      choice([
        whitespace,
        declaration,
        string("(") |> token(:punctuation),
        string(")") |> token(:punctuation),
        string("|") |> token(:operator),
        string("+") |> token(:operator),
        string("?") |> token(:operator),
        string("*") |> token(:operator),
        attribute_value_double,
        attribute_value_single,
        xml_name,
        utf8_char([]) |> token(:text)
      ]),
      "[",
      "]",
      :punctuation
    )

  # Doctype
  doctype =
    string("<!DOCTYPE")
    |> token(:name_tag)
    |> concat(whitespace)
    |> concat(token(xml_name, :name_class))
    |> optional(whitespace)
    |> choice([
      doctype_inner,
      repeat(lookahead_not(string(">")) |> utf8_char([]))
      |> lexeme()
      |> token(:text)
    ])
    |> optional(whitespace)
    |> concat(token(string(">"), :name_tag))

  # Opening tags with optional attributes
  open_tag =
    token(string("<"), :punctuation)
    |> optional(whitespace)
    |> concat(token(xml_name, :name_tag))
    |> concat(repeat(whitespace |> concat(attribute)))
    |> concat(optional(whitespace))
    |> concat(
      choice([
        token(string("/>"), :punctuation),
        token(string(">"), :punctuation)
      ])
    )

  # Closing tags
  close_tag =
    token(string("</"), :punctuation)
    |> optional(whitespace)
    |> concat(token(xml_name, :name_tag))
    |> concat(optional(whitespace))
    |> concat(token(string(">"), :punctuation))

  # Text content between tags
  text =
    utf8_string([not: ?<, not: ?&], min: 1)
    |> token(:text)

  # Any char as error fallback
  any_char = utf8_char([]) |> token(:error)

  root_element_combinator =
    choice([
      whitespace,
      cdata,
      comment,
      processing_instruction,
      doctype,
      open_tag,
      close_tag,
      entity,
      text,
      any_char
    ])

  @inline false

  @doc false
  def __as_xml_language__({ttype, meta, value}) do
    {ttype, Map.put(meta, :language, :xml), value}
  end

  defparsec(
    :root_element,
    root_element_combinator |> map({__MODULE__, :__as_xml_language__, []}),
    inline: @inline,
    export_combinator: true
  )

  defparsec(
    :root,
    repeat(parsec(:root_element)),
    inline: @inline,
    export_combinator: true
  )

  defcombinator(:attribute, attribute)
  defcombinator(:attribute_value, attribute_value)

  defparsec(:test, attribute_value)

  ###################################################################
  # Step #2: postprocess the list of tokens
  ###################################################################

  defp postprocess_helper([token | tokens]), do: [token | postprocess_helper(tokens)]
  defp postprocess_helper([]), do: []

  @impl Makeup.Lexer
  def postprocess(tokens, _opts \\ []), do: postprocess_helper(tokens)

  ###################################################################
  # Step #3: highlight matching delimiters
  ###################################################################

  @impl Makeup.Lexer
  defgroupmatcher(:match_groups,
    comment_tag: [
      open: [[{:punctuation, _, "<!--"}]],
      close: [[{:punctuation, _, "-->"}]]
    ],
    start_closing_tag: [
      open: [[{:punctuation, _, "</"}]],
      close: [[{:punctuation, _, ">"}]]
    ],
    start_tag: [
      open: [[{:punctuation, _, "<"}]],
      close: [[{:punctuation, _, ">"}], [{:punctuation, _, "/>"}]]
    ]
  )

  # Public API
  @impl Makeup.Lexer
  def lex(text, opts \\ []) do
    group_prefix = Keyword.get(opts, :group_prefix, random_prefix(10))

    {:ok, tokens, "", _, _, _} = root(text)

    tokens
    |> postprocess([])
    |> match_groups(group_prefix)
  end
end
