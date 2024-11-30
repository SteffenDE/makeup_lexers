defmodule MakeupLexers.HTMLLexerTest do
  use ExUnit.Case, async: true
  alias MakeupLexers.HTMLLexer

  # Helper function to lex and return tokens without metadata
  defp lex(text) do
    text
    |> HTMLLexer.lex()
    |> Enum.map(fn {type, _meta, value} -> {type, IO.iodata_to_binary([value])} end)
  end

  defp refute_any_errors(tokens) do
    assert Enum.all?(tokens, fn {type, _} -> type != :error end)
  end

  describe "embedded lexers" do
    test "lexes text/javascript with JavascriptLexer" do
      assert lex("""
             <h1>Hello</h1>
             <script type="text/javascript">
               console.log("Hello, world!");
             </script>
             """) == [
               {:punctuation, "<"},
               {:name_tag, "h1"},
               {:punctuation, ">"},
               {:text, "Hello"},
               {:punctuation, "</"},
               {:name_tag, "h1"},
               {:punctuation, ">"},
               {:whitespace, "\n"},
               {:punctuation, "<"},
               {:name_tag, "script"},
               {:whitespace, " "},
               {:name_attribute, "type"},
               {:operator, "="},
               {:string, "\""},
               {:string, "text/javascript"},
               {:string, "\""},
               {:punctuation, ">"},
               {:whitespace, "\n  "},
               {:name_builtin, "console"},
               {:punctuation, "."},
               {:name_function, "log"},
               {:punctuation, "("},
               {:string_double, "\"Hello, world!\""},
               {:punctuation, ")"},
               {:punctuation, ";"},
               {:whitespace, "\n"},
               {:punctuation, "</"},
               {:name_tag, "script"},
               {:punctuation, ">"},
               {:whitespace, "\n"}
             ]
    end

    test "lexes script with no type with JavascriptLexer" do
      assert lex("""
             <script>
               console.log("Hello, world!");
             </script>
             """) == [
               {:punctuation, "<"},
               {:name_tag, "script"},
               {:punctuation, ">"},
               {:whitespace, "\n  "},
               {:name_builtin, "console"},
               {:punctuation, "."},
               {:name_function, "log"},
               {:punctuation, "("},
               {:string_double, "\"Hello, world!\""},
               {:punctuation, ")"},
               {:punctuation, ";"},
               {:whitespace, "\n"},
               {:punctuation, "</"},
               {:name_tag, "script"},
               {:punctuation, ">"},
               {:whitespace, "\n"}
             ]
    end

    test "does not lex other types" do
      assert lex("""
             <script type="text/typescript">
               console.log("Hello, world!");
             </script>
             """) == [
               {:punctuation, "<"},
               {:name_tag, "script"},
               {:whitespace, " "},
               {:name_attribute, "type"},
               {:operator, "="},
               {:string, "\""},
               {:string, "text/typescript"},
               {:string, "\""},
               {:punctuation, ">"},
               {:text, "\n  console.log(\"Hello, world!\");\n"},
               {:punctuation, "</"},
               {:name_tag, "script"},
               {:punctuation, ">"},
               {:whitespace, "\n"}
             ]
    end

    test "lexes style with CSSLexer" do
      assert lex("""
             <h1>Hello</h1>
             <style>
               body {
                 background-color: red;
               }
             </style>
             """) == [
               punctuation: "<",
               name_tag: "h1",
               punctuation: ">",
               text: "Hello",
               punctuation: "</",
               name_tag: "h1",
               punctuation: ">",
               whitespace: "\n",
               punctuation: "<",
               name_tag: "style",
               punctuation: ">",
               whitespace: "\n  ",
               name: "body",
               whitespace: " ",
               punctuation: "{",
               whitespace: "\n    ",
               name_builtin: "background-color",
               punctuation: ":",
               whitespace: " ",
               name_constant: "red",
               punctuation: ";",
               whitespace: "\n  ",
               punctuation: "}",
               whitespace: "\n",
               punctuation: "</",
               name_tag: "style",
               punctuation: ">",
               whitespace: "\n"
             ]
    end
  end

  describe "doctype" do
    test "case insensitive doctype" do
      # https://html.spec.whatwg.org/multipage/syntax.html#the-doctype
      assert lex("<!doctype html>") == [{:comment_preproc, "<!doctype html>"}]
      assert lex("<!DocType html>") == [{:comment_preproc, "<!DocType html>"}]

      assert lex(~s[<!DOCTYPE html SYSTEM "about:legacy-compat">]) == [
               {:comment_preproc, "<!DOCTYPE html SYSTEM \"about:legacy-compat\">"}
             ]

      assert lex(~s[<!DOCTYPE html SYSTEM 'about:legacy-compat'>]) == [
               {:comment_preproc, "<!DOCTYPE html SYSTEM 'about:legacy-compat'>"}
             ]
    end
  end

  describe "attributes" do
    test "allows attributes without value" do
      assert lex("<input disabled>") == [
               {:punctuation, "<"},
               {:name_tag, "input"},
               {:whitespace, " "},
               {:name_attribute, "disabled"},
               {:punctuation, ">"}
             ]
    end

    test "attributes don't need to be quoted" do
      assert lex("<input type=text>") == [
               {:punctuation, "<"},
               {:name_tag, "input"},
               {:whitespace, " "},
               {:name_attribute, "type"},
               {:operator, "="},
               {:string, "text"},
               {:punctuation, ">"}
             ]
    end

    test "single or double quoted values" do
      assert lex("<input type=\"text\">") == [
               {:punctuation, "<"},
               {:name_tag, "input"},
               {:whitespace, " "},
               {:name_attribute, "type"},
               {:operator, "="},
               {:string, "\""},
               {:string, "text"},
               {:string, "\""},
               {:punctuation, ">"}
             ]

      assert lex("<input type=\'text\'>") == [
               {:punctuation, "<"},
               {:name_tag, "input"},
               {:whitespace, " "},
               {:name_attribute, "type"},
               {:operator, "="},
               {:string, "'"},
               {:string, "text"},
               {:string, "'"},
               {:punctuation, ">"}
             ]
    end
  end

  test "we don't care about missing end tags" do
    # they are sometimes optional: https://html.spec.whatwg.org/multipage/syntax.html#optional-tags
    refute_any_errors(
      lex("""
      <table>
      <caption>37547 TEE Electric Powered Rail Car Train Functions (Abbreviated)
      <colgroup><col><col><col>
      <thead>
      <tr>
      <th>Function
      <th>Control Unit
      <th>Central Station
      <tbody>
      <tr>
      <td>Headlights
      <td>✔
      <td>✔
      <tr>
      <td>Interior Lights
      <td>✔
      <td>✔
      <tr>
      <td>Electric locomotive operating sounds
      <td>✔
      <td>✔
      <tr>
      <td>Engineer's cab lighting
      <td>
      <td>✔
      <tr>
      <td>Station Announcements - Swiss
      <td>
      <td>✔
      </table>
      """)
    )
  end

  test "empty attributes are handled (HEEx)" do
    assert lex("""
           <button type= class="rounded-lg bg-zinc-900 hover:bg-zinc-700 py-2 px-3 text-white"></button>
           """) == [
             {:punctuation, "<"},
             {:name_tag, "button"},
             {:whitespace, " "},
             {:name_attribute, "type"},
             {:operator, "="},
             {:whitespace, " "},
             {:name_attribute, "class"},
             {:operator, "="},
             {:string, "\""},
             {:string, "rounded-lg bg-zinc-900 hover:bg-zinc-700 py-2 px-3 text-white"},
             {:string, "\""},
             {:punctuation, ">"},
             {:punctuation, "</"},
             {:name_tag, "button"},
             {:punctuation, ">"},
             {:whitespace, "\n"}
           ]
  end
end
