defmodule MakeupLexers.CSSLexerTest do
  use ExUnit.Case, async: true
  alias MakeupLexers.CSSLexer

  # Helper function to lex and return tokens
  defp lex(text) do
    text
    |> CSSLexer.lex()
    |> Enum.map(fn {type, _meta, value} -> {type, IO.iodata_to_binary([value])} end)
  end

  describe "numbers" do
    test "integers" do
      assert lex("42") == [{:number, "42"}]
    end

    test "floats" do
      assert lex("3.14159") == [{:number, "3.14159"}]
    end

    test "numbers with units" do
      assert lex("10px") == [{:number, "10px"}]
      assert lex("2em") == [{:number, "2em"}]
      assert lex("50%") == [{:number, "50%"}]
      assert lex("90deg") == [{:number, "90deg"}]
      assert lex("2s") == [{:number, "2s"}]
      assert lex("300ms") == [{:number, "300ms"}]
    end

    test "negative numbers" do
      assert lex("-42") == [{:number, "-42"}]
      assert lex("-10px") == [{:number, "-10px"}]
    end
  end

  describe "colors" do
    test "hex colors" do
      assert lex("#fff") == [{:string_symbol, "#fff"}]
      assert lex("#FF0000") == [{:string_symbol, "#FF0000"}]
    end

    test "color keywords" do
      assert lex("red") == [{:name_constant, "red"}]
      assert lex("blue") == [{:name_constant, "blue"}]
    end
  end

  describe "strings" do
    test "single quoted strings" do
      assert lex("'hello'") == [{:string_single, "'hello'"}]
    end

    test "double quoted strings" do
      assert lex("\"world\"") == [{:string_double, "\"world\""}]
    end

    test "strings with escapes" do
      assert lex("'It\\'s'") == [
               {:string_single, "'It"},
               {:string_escape, "\\'"},
               {:string_single, "s'"}
             ]
    end
  end

  describe "comments" do
    test "multiline comments" do
      assert lex("/* comment */") == [{:comment_multiline, "/* comment */"}]
      assert lex("/* multi\nline */") == [{:comment_multiline, "/* multi\nline */"}]
    end
  end

  describe "selectors" do
    test "type selectors" do
      assert lex("div") == [{:name, "div"}]
    end

    test "class selectors" do
      assert lex(".container") == [{:name_class, ".container"}]
    end

    test "id selectors" do
      assert lex("#header") == [{:name_label, "#header"}]
    end

    test "pseudo selectors" do
      assert lex(":hover") == [{:name_decorator, ":hover"}]
      assert lex("::before") == [{:name_decorator, "::before"}]
    end

    test "attribute selectors" do
      assert lex("[type]") == [
               {:punctuation, "["},
               {:name, "type"},
               {:punctuation, "]"}
             ]

      assert lex("[type='text']") == [
               {:punctuation, "["},
               {:name, "type"},
               {:operator, "="},
               {:string_single, "'text'"},
               {:punctuation, "]"}
             ]

      assert lex("[lang|='en']") == [
               {:punctuation, "["},
               {:name, "lang"},
               {:operator, "|="},
               {:string_single, "'en'"},
               {:punctuation, "]"}
             ]
    end

    test "combinators" do
      assert lex("div > p") == [
               {:name, "div"},
               {:whitespace, " "},
               {:operator, ">"},
               {:whitespace, " "},
               {:name, "p"}
             ]

      assert lex("div + p") == [
               {:name, "div"},
               {:whitespace, " "},
               {:operator, "+"},
               {:whitespace, " "},
               {:name, "p"}
             ]
    end
  end

  describe "properties" do
    test "standard properties" do
      assert lex("color: red;") == [
               {:name_builtin, "color"},
               {:punctuation, ":"},
               {:whitespace, " "},
               {:name_constant, "red"},
               {:punctuation, ";"}
             ]
    end

    test "vendor prefixed properties" do
      assert lex("-webkit-transform") == [{:name, "-webkit-transform"}]
    end
  end

  describe "at-rules" do
    test "basic at-rules" do
      assert lex("@media") == [{:keyword_declaration, "@media"}]
      assert lex("@import") == [{:keyword_declaration, "@import"}]
    end

    test "complete at-rules" do
      assert lex("@media screen {") == [
               {:keyword_declaration, "@media"},
               {:whitespace, " "},
               {:name_builtin_pseudo, "screen"},
               {:whitespace, " "},
               {:punctuation, "{"}
             ]
    end
  end

  describe "functions" do
    test "basic functions" do
      assert lex("rgb(255, 0, 0)") == [
               {:name_function, "rgb"},
               {:punctuation, "("},
               {:number, "255"},
               {:punctuation, ","},
               {:whitespace, " "},
               {:number, "0"},
               {:punctuation, ","},
               {:whitespace, " "},
               {:number, "0"},
               {:punctuation, ")"}
             ]
    end

    test "url function" do
      assert lex("url('image.jpg')") == [
               {:name_function, "url"},
               {:punctuation, "("},
               {:string_single, "'image.jpg'"},
               {:punctuation, ")"}
             ]
    end

    test "calc function" do
      assert lex("calc(100% - 20px)") == [
               {:name_function, "calc"},
               {:punctuation, "("},
               {:number, "100%"},
               {:whitespace, " "},
               {:operator, "-"},
               {:whitespace, " "},
               {:number, "20px"},
               {:punctuation, ")"}
             ]
    end
  end

  describe "css variables" do
    test "variable declaration" do
      assert lex("--primary-color") == [{:name_variable, "--primary-color"}]
    end

    test "var function" do
      assert lex("var(--primary-color)") == [
               {:name_function, "var"},
               {:punctuation, "("},
               {:name_variable, "--primary-color"},
               {:punctuation, ")"}
             ]
    end

    test "var function with fallback" do
      assert lex("var(--primary-color, blue)") == [
               {:name_function, "var"},
               {:punctuation, "("},
               {:name_variable, "--primary-color"},
               {:punctuation, ","},
               {:whitespace, " "},
               {:name_constant, "blue"},
               {:punctuation, ")"}
             ]
    end
  end

  describe "match groups" do
    test "braces, parentheses, and brackets" do
      assert [
               {:name_function, _, "calc"},
               {:punctuation, %{group_id: first}, "("},
               {:number, _, ["100", "%"]},
               {:whitespace, _, " "},
               {:operator, _, "-"},
               {:whitespace, _, " "},
               {:punctuation, %{group_id: second}, "("},
               {:number, _, ["20", "px"]},
               {:whitespace, _, " "},
               {:operator, _, "+"},
               {:whitespace, _, " "},
               {:number, _, ["10", "px"]},
               {:punctuation, %{group_id: second}, ")"},
               {:punctuation, %{group_id: first}, ")"}
             ] = CSSLexer.lex("calc(100% - (20px + 10px))")

      assert [
               {:name_class, _, ".test"},
               {:whitespace, _, " "},
               {:punctuation, %{group_id: first}, "{"},
               {:whitespace, _, " "},
               {:name_builtin, _, "color"},
               {:punctuation, _, ":"},
               {:whitespace, _, " "},
               {:punctuation, %{group_id: second}, "["},
               {:name, _, "attr"},
               {:punctuation, %{group_id: second}, "]"},
               {:punctuation, _, ";"},
               {:whitespace, _, " "},
               {:punctuation, %{group_id: first}, "}"}
             ] = CSSLexer.lex(".test { color: [attr]; }")
    end
  end
end
