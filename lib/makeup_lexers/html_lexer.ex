defmodule MakeupLexers.HTMLLexer do
  @moduledoc """
  A `Makeup` lexer for HTML (HyperText Markup Language).
  """

  @behaviour Makeup.Lexer

  import NimbleParsec
  import Makeup.Lexer.Combinators
  import Makeup.Lexer.Groups

  xml_lexer = parsec({MakeupLexers.XMLLexer, :root_element})
  attribute = parsec({MakeupLexers.XMLLexer, :attribute})
  attribute_value = parsec({MakeupLexers.XMLLexer, :attribute_value})

  whitespace = ascii_string([?\r, ?\s, ?\n, ?\t], min: 1) |> token(:whitespace)

  type_attribute =
    string("type")
    |> token(:name_attribute)
    |> concat(optional(whitespace))
    |> concat(token(string("="), :operator))
    |> concat(optional(whitespace))
    |> concat(attribute_value |> map(:put_script_type))

  defp put_script_type({ttype, meta, value}) when value not in ["'", "\""] do
    {ttype, Map.put(meta, :script_type, value), value}
  end

  defp put_script_type({ttype, meta, value}) do
    {ttype, meta, value}
  end

  script_content =
    repeat(
      lookahead_not(string(">"))
      |> choice([
        type_attribute,
        whitespace,
        attribute
      ])
    )
    |> concat(token(string(">"), :punctuation))
    |> concat(
      repeat(lookahead_not(string("</script>")) |> utf8_char([]))
      |> lexeme()
      |> token(:script_content)
    )

  script = many_surrounded_by(script_content, string("<script"), string("</script>"), :script)

  root_element_combinator =
    choice([
      script,
      xml_lexer
    ])

  @inline false

  @doc false
  def __as_html_language__({ttype, meta, value}) do
    {ttype, Map.put(meta, :language, :html), value}
  end

  defparsec(
    :root_element,
    root_element_combinator |> map({__MODULE__, :__as_html_language__, []}),
    inline: @inline,
    export_combinator: true
  )

  defparsec(
    :root,
    repeat(parsec(:root_element)),
    inline: @inline,
    export_combinator: true
  )

  defparsec(:script, script)

  defp postprocess_helper([{:script, _, "<script"} | rest]) do
    {script_tokens, rest} = get_script(rest, [])

    type =
      Enum.find_value(script_tokens, "text/javascript", fn
        {:string, %{script_type: type}, _} -> type
        _ -> nil
      end)

    {{pre_content, content, post_content}, _} =
      Enum.reduce(script_tokens, {{[], nil, []}, false}, fn
        {:script_content, _, content}, {{pre, _, post}, false} -> {{pre, content, post}, true}
        token, {{pre, content, post}, false} -> {{[token | pre], content, post}, false}
        token, {{pre, content, post}, true} -> {{pre, content, [token | post]}, true}
      end)

    lexed_script =
      if type == "text/javascript" do
        MakeupLexers.JavascriptLexer.lex(content)
      else
        [{:text, %{language: :html}, content}]
      end

    [
      {:punctuation, %{language: :html}, "<"},
      {:name_tag, %{language: :html}, "script"}
    ] ++
      Enum.reverse(pre_content) ++
      lexed_script ++
      Enum.reverse(post_content) ++
      [
        {:punctuation, %{language: :html}, "</"},
        {:name_tag, %{language: :html}, "script"},
        {:punctuation, %{language: :html}, ">"}
      ] ++ postprocess_helper(rest)
  end

  defp postprocess_helper([token | tokens]), do: [token | postprocess_helper(tokens)]
  defp postprocess_helper([]), do: []

  defp get_script([], acc), do: {Enum.reverse(acc), []}

  defp get_script([{:script, _, "</script>"} | rest], acc) do
    {Enum.reverse(acc), rest}
  end

  defp get_script([token | rest], acc), do: get_script(rest, [token | acc])

  @impl Makeup.Lexer
  defgroupmatcher(:match_groups, [])

  @impl Makeup.Lexer
  def postprocess(tokens, _opts \\ []), do: postprocess_helper(tokens)

  @impl Makeup.Lexer
  def lex(text, _opts \\ []) do
    {:ok, tokens, "", _, _, _} = root(text)

    tokens
    |> postprocess([])
  end
end
