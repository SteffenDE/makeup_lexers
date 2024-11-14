defmodule MakeupLexers.HTMLLexerTest do
  use ExUnit.Case, async: true
  alias MakeupLexers.HTMLLexer

  # Helper function to lex and return tokens without metadata
  defp lex(text) do
    text
    |> HTMLLexer.lex()
    |> Enum.map(fn {type, _meta, value} -> {type, IO.iodata_to_binary([value])} end)
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

  test "allows attributes without value" do
    assert lex("<input disabled>") == [
             {:punctuation, "<"},
             {:name_tag, "input"},
             {:whitespace, " "},
             {:name_attribute, "disabled"},
             {:punctuation, ">"}
           ]
  end
end
