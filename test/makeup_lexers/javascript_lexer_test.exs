defmodule MakeupLexers.JavascriptLexerTest do
  use ExUnit.Case, async: true
  alias MakeupLexers.JavascriptLexer

  # Helper function to lex and return tokens
  defp lex(text) do
    text
    |> JavascriptLexer.lex()
    |> Enum.map(fn {type, _meta, value} -> {type, IO.iodata_to_binary([value])} end)
  end

  describe "numbers" do
    test "integers" do
      assert lex("42") == [{:number_integer, "42"}]
    end

    test "floats" do
      assert lex("3.14159") == [{:number_float, "3.14159"}]
    end

    test "scientific notation" do
      assert lex("1.23e-4") == [{:number_float, "1.23e-4"}]
    end

    test "hex numbers" do
      assert lex("0xFF") == [{:number_hex, "0xFF"}]
    end

    test "binary numbers" do
      assert lex("0b1010") == [{:number_bin, "0b1010"}]
    end

    test "octal numbers" do
      assert lex("0o777") == [{:number_oct, "0o777"}]
    end

    test "bigint" do
      assert lex("9007199254740991n") == [{:number_integer, "9007199254740991n"}]
    end
  end

  describe "strings" do
    test "single quoted strings" do
      assert lex("'hello'") == [{:string_single, "'hello'"}]
    end

    test "double quoted strings" do
      assert lex("\"world\"") == [{:string_double, "\"world\""}]
    end

    test "template literals" do
      assert lex("`Hello ${name}`") == [
               {:string_backtick, "`Hello "},
               {:string_interpol, "${"},
               {:name, "name"},
               {:string_interpol, "}"},
               {:string_backtick, "`"}
             ]
    end

    test "escaped characters in strings" do
      assert lex("'It\\'s \\u1234'") == [
               {:string_single, "'It"},
               {:string_escape, "\\'"},
               {:string_single, "s "},
               {:string_escape, "\\u1234"},
               {:string_single, "'"}
             ]
    end
  end

  describe "comments" do
    test "single line comments" do
      assert lex("// comment") == [{:comment_single, "// comment"}]
    end

    test "multiline comments" do
      assert lex("/* multi\nline */") == [{:comment_multiline, "/* multi\nline */"}]
    end

    test "hashbang" do
      assert lex("#!/usr/bin/env node") == [{:comment_hashbang, "#!/usr/bin/env node"}]
    end
  end

  describe "identifiers and keywords" do
    test "basic identifiers" do
      assert lex("myVariable") == [{:name, "myVariable"}]
    end

    test "class names" do
      assert lex("MyClass") == [{:name_class, "MyClass"}]
    end

    test "keywords" do
      assert lex("if") == [{:keyword, "if"}]
      assert lex("else") == [{:keyword, "else"}]
      assert lex("return") == [{:keyword, "return"}]
    end

    test "declarations" do
      assert lex("const") == [{:keyword_declaration, "const"}]
      assert lex("let") == [{:keyword_declaration, "let"}]
      assert lex("class") == [{:keyword_declaration, "class"}]
    end

    test "operator words" do
      assert lex("typeof") == [{:operator_word, "typeof"}]
      assert lex("instanceof") == [{:operator_word, "instanceof"}]
      assert lex("in") == [{:operator_word, "in"}]
      assert lex("void") == [{:operator_word, "void"}]
      assert lex("delete") == [{:operator_word, "delete"}]
      assert lex("new") == [{:operator_word, "new"}]
    end

    test "constants" do
      assert lex("true") == [{:name_constant, "true"}]
      assert lex("null") == [{:name_constant, "null"}]
      assert lex("undefined") == [{:name_constant, "undefined"}]
    end

    test "builtins" do
      assert lex("console") == [{:name_builtin, "console"}]
      assert lex("Math") == [{:name_builtin, "Math"}]
    end
  end

  describe "regular expressions" do
    test "simple regex" do
      assert lex("/test/") == [{:string_regex, "/test/"}]
    end

    test "regex with flags" do
      assert lex("/test/gi") == [{:string_regex, "/test/gi"}]
    end

    test "regex with character class" do
      assert lex("/[a-z]/") == [{:string_regex, "/[a-z]/"}]
    end

    test "regex with escape sequences" do
      assert lex("/\\w+\\/\\d/") == [{:string_regex, "/\\w+\\/\\d/"}]
    end
  end

  describe "operators and punctuation" do
    test "arithmetic operators" do
      assert lex("+ - * /") == [
               {:operator, "+"},
               {:whitespace, " "},
               {:operator, "-"},
               {:whitespace, " "},
               {:operator, "*"},
               {:whitespace, " "},
               {:operator, "/"}
             ]
    end

    test "comparison operators" do
      assert lex("=== !== >= <=") == [
               {:operator, "==="},
               {:whitespace, " "},
               {:operator, "!=="},
               {:whitespace, " "},
               {:operator, ">="},
               {:whitespace, " "},
               {:operator, "<="}
             ]
    end

    test "arrow function operator" do
      assert lex("=>") == [{:punctuation, "=>"}]
    end

    test "punctuation" do
      assert lex("{}[]();,.") == [
               {:punctuation, "{"},
               {:punctuation, "}"},
               {:punctuation, "["},
               {:punctuation, "]"},
               {:punctuation, "("},
               {:punctuation, ")"},
               {:punctuation, ";"},
               {:punctuation, ","},
               {:punctuation, "."}
             ]
    end
  end

  describe "function detection" do
    test "function declaration" do
      assert lex("function test() {}") == [
               keyword_declaration: "function",
               whitespace: " ",
               name_function: "test",
               punctuation: "(",
               punctuation: ")",
               whitespace: " ",
               punctuation: "{",
               punctuation: "}"
             ]
    end

    test "method calls" do
      assert lex("object.method()") == [
               name: "object",
               punctuation: ".",
               name_function: "method",
               punctuation: "(",
               punctuation: ")"
             ]
    end

    test "arrow functions" do
      assert lex("const fn = (x) => x * 2") == [
               keyword_declaration: "const",
               whitespace: " ",
               name_function: "fn",
               whitespace: " ",
               operator: "=",
               whitespace: " ",
               punctuation: "(",
               name: "x",
               punctuation: ")",
               whitespace: " ",
               punctuation: "=>",
               whitespace: " ",
               name: "x",
               whitespace: " ",
               operator: "*",
               whitespace: " ",
               number_integer: "2"
             ]

      assert lex("x = () => {}") == [
               {:name_function, "x"},
               {:whitespace, " "},
               {:operator, "="},
               {:whitespace, " "},
               {:punctuation, "("},
               {:punctuation, ")"},
               {:whitespace, " "},
               {:punctuation, "=>"},
               {:whitespace, " "},
               {:punctuation, "{"},
               {:punctuation, "}"}
             ]

      assert lex("y = x => {}") == [
               {:name_function, "y"},
               {:whitespace, " "},
               {:operator, "="},
               {:whitespace, " "},
               {:name, "x"},
               {:whitespace, " "},
               {:punctuation, "=>"},
               {:whitespace, " "},
               {:punctuation, "{"},
               {:punctuation, "}"}
             ]

      assert lex("y = ({x, y, z}) => {}") == [
               {:name_function, "y"},
               {:whitespace, " "},
               {:operator, "="},
               {:whitespace, " "},
               {:punctuation, "("},
               {:punctuation, "{"},
               {:name, "x"},
               {:punctuation, ","},
               {:whitespace, " "},
               {:name, "y"},
               {:punctuation, ","},
               {:whitespace, " "},
               {:name, "z"},
               {:punctuation, "}"},
               {:punctuation, ")"},
               {:whitespace, " "},
               {:punctuation, "=>"},
               {:whitespace, " "},
               {:punctuation, "{"},
               {:punctuation, "}"}
             ]
    end
  end

  describe "special features" do
    test "private class fields" do
      assert lex("#privateField") == [{:name_property, "#privateField"}]
    end

    test "nullish coalescing" do
      assert lex("??") == [{:operator, "??"}]
    end

    test "optional chaining" do
      assert lex("?.") == [{:operator, "?."}]
    end
  end

  describe "function parameters" do
    test "default parameters" do
      assert lex("function test(a, b = 1) {}") == [
               keyword_declaration: "function",
               whitespace: " ",
               name_function: "test",
               punctuation: "(",
               name: "a",
               punctuation: ",",
               whitespace: " ",
               name: "b",
               whitespace: " ",
               operator: "=",
               whitespace: " ",
               number_integer: "1",
               punctuation: ")",
               whitespace: " ",
               punctuation: "{",
               punctuation: "}"
             ]
    end
  end

  describe "object methods and properties" do
    test "method shorthand" do
      assert lex("const obj = { method() {} }") == [
               keyword_declaration: "const",
               whitespace: " ",
               name: "obj",
               whitespace: " ",
               operator: "=",
               whitespace: " ",
               punctuation: "{",
               whitespace: " ",
               name_function: "method",
               punctuation: "(",
               punctuation: ")",
               whitespace: " ",
               punctuation: "{",
               punctuation: "}",
               whitespace: " ",
               punctuation: "}"
             ]
    end

    test "getter and setter" do
      assert lex("const obj = { get name() {}, set name(value) {} }") == [
               keyword_declaration: "const",
               whitespace: " ",
               name: "obj",
               whitespace: " ",
               operator: "=",
               whitespace: " ",
               punctuation: "{",
               whitespace: " ",
               keyword: "get",
               whitespace: " ",
               name_function: "name",
               punctuation: "(",
               punctuation: ")",
               whitespace: " ",
               punctuation: "{",
               punctuation: "}",
               punctuation: ",",
               whitespace: " ",
               keyword: "set",
               whitespace: " ",
               name_function: "name",
               punctuation: "(",
               name: "value",
               punctuation: ")",
               whitespace: " ",
               punctuation: "{",
               punctuation: "}",
               whitespace: " ",
               punctuation: "}"
             ]
    end

    test "computed property names" do
      assert lex("const obj = { ['computed-key']: value }") == [
               keyword_declaration: "const",
               whitespace: " ",
               name: "obj",
               whitespace: " ",
               operator: "=",
               whitespace: " ",
               punctuation: "{",
               whitespace: " ",
               punctuation: "[",
               string_single: "'computed-key'",
               punctuation: "]",
               operator: ":",
               whitespace: " ",
               name: "value",
               whitespace: " ",
               punctuation: "}"
             ]
    end
  end

  describe "class features" do
    test "static members" do
      assert lex("class Test { static field = 42; static method() {} }") == [
               keyword_declaration: "class",
               whitespace: " ",
               name_class: "Test",
               whitespace: " ",
               punctuation: "{",
               whitespace: " ",
               keyword: "static",
               whitespace: " ",
               name: "field",
               whitespace: " ",
               operator: "=",
               whitespace: " ",
               number_integer: "42",
               punctuation: ";",
               whitespace: " ",
               keyword: "static",
               whitespace: " ",
               name_function: "method",
               punctuation: "(",
               punctuation: ")",
               whitespace: " ",
               punctuation: "{",
               punctuation: "}",
               whitespace: " ",
               punctuation: "}"
             ]
    end
  end

  describe "bitwise operations" do
    test "basic bitwise operators" do
      assert lex("a & b | c ^ d << e >> f >>> g") == [
               name: "a",
               whitespace: " ",
               operator: "&",
               whitespace: " ",
               name: "b",
               whitespace: " ",
               operator: "|",
               whitespace: " ",
               name: "c",
               whitespace: " ",
               operator: "^",
               whitespace: " ",
               name: "d",
               whitespace: " ",
               operator: "<<",
               whitespace: " ",
               name: "e",
               whitespace: " ",
               operator: ">>",
               whitespace: " ",
               name: "f",
               whitespace: " ",
               operator: ">>>",
               whitespace: " ",
               name: "g"
             ]
    end
  end

  describe "assignment operators" do
    test "logical assignment operators" do
      assert lex("x &&= y ||= z ??= w") == [
               name: "x",
               whitespace: " ",
               operator: "&&=",
               whitespace: " ",
               name: "y",
               whitespace: " ",
               operator: "||=",
               whitespace: " ",
               name: "z",
               whitespace: " ",
               operator: "??=",
               whitespace: " ",
               name: "w"
             ]
    end
  end

  describe "error handling" do
    test "try-catch blocks" do
      assert lex("try { throw new Error() } catch (e) {}") == [
               keyword: "try",
               whitespace: " ",
               punctuation: "{",
               whitespace: " ",
               keyword: "throw",
               whitespace: " ",
               operator_word: "new",
               whitespace: " ",
               name_builtin: "Error",
               punctuation: "(",
               punctuation: ")",
               whitespace: " ",
               punctuation: "}",
               whitespace: " ",
               keyword: "catch",
               whitespace: " ",
               punctuation: "(",
               name: "e",
               punctuation: ")",
               whitespace: " ",
               punctuation: "{",
               punctuation: "}"
             ]
    end
  end

  describe "control flow" do
    test "break and continue statements" do
      assert lex("outer: for(;;) { break outer; continue; }") == [
               name: "outer",
               operator: ":",
               whitespace: " ",
               keyword: "for",
               punctuation: "(",
               punctuation: ";",
               punctuation: ";",
               punctuation: ")",
               whitespace: " ",
               punctuation: "{",
               whitespace: " ",
               keyword: "break",
               whitespace: " ",
               name: "outer",
               punctuation: ";",
               whitespace: " ",
               keyword: "continue",
               punctuation: ";",
               whitespace: " ",
               punctuation: "}"
             ]
    end

    test "labeled statements" do
      assert lex("label: console.log()") == [
               name: "label",
               operator: ":",
               whitespace: " ",
               name_builtin: "console",
               punctuation: ".",
               name_function: "log",
               punctuation: "(",
               punctuation: ")"
             ]
    end
  end

  describe "complex cases" do
    test "class definition with methods" do
      code = """
      class Example {
        constructor() {}
        method() {}
      }
      """

      assert lex(code) == [
               keyword_declaration: "class",
               whitespace: " ",
               name_class: "Example",
               whitespace: " ",
               punctuation: "{",
               whitespace: "\n  ",
               keyword: "constructor",
               punctuation: "(",
               punctuation: ")",
               whitespace: " ",
               punctuation: "{",
               punctuation: "}",
               whitespace: "\n  ",
               name_function: "method",
               punctuation: "(",
               punctuation: ")",
               whitespace: " ",
               punctuation: "{",
               punctuation: "}",
               whitespace: "\n",
               punctuation: "}",
               whitespace: "\n"
             ]
    end

    test "async/await functions" do
      code = """
      async function getData() {
        const result = await fetch();
      }
      """

      assert lex(code) == [
               keyword: "async",
               whitespace: " ",
               keyword_declaration: "function",
               whitespace: " ",
               name_function: "getData",
               punctuation: "(",
               punctuation: ")",
               whitespace: " ",
               punctuation: "{",
               whitespace: "\n  ",
               keyword_declaration: "const",
               whitespace: " ",
               name: "result",
               whitespace: " ",
               operator: "=",
               whitespace: " ",
               keyword: "await",
               whitespace: " ",
               name_function: "fetch",
               punctuation: "(",
               punctuation: ")",
               punctuation: ";",
               whitespace: "\n",
               punctuation: "}",
               whitespace: "\n"
             ]
    end

    test "template literal with nested expressions" do
      code = "`Value: ${obj.method()} nested ${1 + 2}`"

      assert lex(code) == [
               string_backtick: "`Value: ",
               string_interpol: "${",
               name: "obj",
               punctuation: ".",
               name_function: "method",
               punctuation: "(",
               punctuation: ")",
               string_interpol: "}",
               string_backtick: " nested ",
               string_interpol: "${",
               number_integer: "1",
               whitespace: " ",
               operator: "+",
               whitespace: " ",
               number_integer: "2",
               string_interpol: "}",
               string_backtick: "`"
             ]
    end
  end

  describe "modules imports / exports" do
    test "simple" do
      assert lex("export const x = 1; export default class {}; import { y } from 'mod';") == [
               keyword_namespace: "export",
               whitespace: " ",
               keyword_declaration: "const",
               whitespace: " ",
               name: "x",
               whitespace: " ",
               operator: "=",
               whitespace: " ",
               number_integer: "1",
               punctuation: ";",
               whitespace: " ",
               keyword_namespace: "export",
               whitespace: " ",
               keyword_namespace: "default",
               whitespace: " ",
               keyword_declaration: "class",
               whitespace: " ",
               punctuation: "{",
               punctuation: "}",
               punctuation: ";",
               whitespace: " ",
               keyword_namespace: "import",
               whitespace: " ",
               punctuation: "{",
               whitespace: " ",
               name: "y",
               whitespace: " ",
               punctuation: "}",
               whitespace: " ",
               keyword_namespace: "from",
               whitespace: " ",
               string_single: "'mod'",
               punctuation: ";"
             ]
    end

    test "from is not classified as keyword_namespace when used outside of import/export" do
      assert lex("function(from, to) {}") == [
               {:keyword_declaration, "function"},
               {:punctuation, "("},
               {:name, "from"},
               {:punctuation, ","},
               {:whitespace, " "},
               {:name, "to"},
               {:punctuation, ")"},
               {:whitespace, " "},
               {:punctuation, "{"},
               {:punctuation, "}"}
             ]
    end

    test "complex" do
      assert lex("""
             import { names } from "module-name" with { key: "data" };
             import { default as alias } from "module-name";
             import { export1 as alias1 } from "module-name";
             import defaultExport, * as name from "module-name";
             import defaultExport, { export1 } from "module-name";
             export const [ name1, name2 ] = array;
             export { default as name1 } from "module-name";
             export { names } from "module-name" with { key: "data", key2: "data2" };
             """) == [
               {:keyword_namespace, "import"},
               {:whitespace, " "},
               {:punctuation, "{"},
               {:whitespace, " "},
               {:name, "names"},
               {:whitespace, " "},
               {:punctuation, "}"},
               {:whitespace, " "},
               {:keyword_namespace, "from"},
               {:whitespace, " "},
               {:string_double, "\"module-name\""},
               {:whitespace, " "},
               {:keyword_namespace, "with"},
               {:whitespace, " "},
               {:punctuation, "{"},
               {:whitespace, " "},
               {:name, "key"},
               {:punctuation, ":"},
               {:whitespace, " "},
               {:string_double, "\"data\""},
               {:whitespace, " "},
               {:punctuation, "}"},
               {:punctuation, ";"},
               {:whitespace, "\n"},
               {:keyword_namespace, "import"},
               {:whitespace, " "},
               {:punctuation, "{"},
               {:whitespace, " "},
               {:keyword_namespace, "default"},
               {:whitespace, " "},
               {:keyword_namespace, "as"},
               {:whitespace, " "},
               {:name, "alias"},
               {:whitespace, " "},
               {:punctuation, "}"},
               {:whitespace, " "},
               {:keyword_namespace, "from"},
               {:whitespace, " "},
               {:string_double, "\"module-name\""},
               {:punctuation, ";"},
               {:whitespace, "\n"},
               {:keyword_namespace, "import"},
               {:whitespace, " "},
               {:punctuation, "{"},
               {:whitespace, " "},
               {:name, "export1"},
               {:whitespace, " "},
               {:keyword_namespace, "as"},
               {:whitespace, " "},
               {:name, "alias1"},
               {:whitespace, " "},
               {:punctuation, "}"},
               {:whitespace, " "},
               {:keyword_namespace, "from"},
               {:whitespace, " "},
               {:string_double, "\"module-name\""},
               {:punctuation, ";"},
               {:whitespace, "\n"},
               {:keyword_namespace, "import"},
               {:whitespace, " "},
               {:name, "defaultExport"},
               {:punctuation, ","},
               {:whitespace, " "},
               {:operator, "*"},
               {:whitespace, " "},
               {:keyword_namespace, "as"},
               {:whitespace, " "},
               {:name, "name"},
               {:whitespace, " "},
               {:keyword_namespace, "from"},
               {:whitespace, " "},
               {:string_double, "\"module-name\""},
               {:punctuation, ";"},
               {:whitespace, "\n"},
               {:keyword_namespace, "import"},
               {:whitespace, " "},
               {:name, "defaultExport"},
               {:punctuation, ","},
               {:whitespace, " "},
               {:punctuation, "{"},
               {:whitespace, " "},
               {:name, "export1"},
               {:whitespace, " "},
               {:punctuation, "}"},
               {:whitespace, " "},
               {:keyword_namespace, "from"},
               {:whitespace, " "},
               {:string_double, "\"module-name\""},
               {:punctuation, ";"},
               {:whitespace, "\n"},
               {:keyword_namespace, "export"},
               {:whitespace, " "},
               {:keyword_declaration, "const"},
               {:whitespace, " "},
               {:punctuation, "["},
               {:whitespace, " "},
               {:name, "name1"},
               {:punctuation, ","},
               {:whitespace, " "},
               {:name, "name2"},
               {:whitespace, " "},
               {:punctuation, "]"},
               {:whitespace, " "},
               {:operator, "="},
               {:whitespace, " "},
               {:name, "array"},
               {:punctuation, ";"},
               {:whitespace, "\n"},
               {:keyword_namespace, "export"},
               {:whitespace, " "},
               {:punctuation, "{"},
               {:whitespace, " "},
               {:keyword_namespace, "default"},
               {:whitespace, " "},
               {:keyword_namespace, "as"},
               {:whitespace, " "},
               {:name, "name1"},
               {:whitespace, " "},
               {:punctuation, "}"},
               {:whitespace, " "},
               {:keyword_namespace, "from"},
               {:whitespace, " "},
               {:string_double, "\"module-name\""},
               {:punctuation, ";"},
               {:whitespace, "\n"},
               {:keyword_namespace, "export"},
               {:whitespace, " "},
               {:punctuation, "{"},
               {:whitespace, " "},
               {:name, "names"},
               {:whitespace, " "},
               {:punctuation, "}"},
               {:whitespace, " "},
               {:keyword_namespace, "from"},
               {:whitespace, " "},
               {:string_double, "\"module-name\""},
               {:whitespace, " "},
               {:keyword_namespace, "with"},
               {:whitespace, " "},
               {:punctuation, "{"},
               {:whitespace, " "},
               {:name, "key"},
               {:punctuation, ":"},
               {:whitespace, " "},
               {:string_double, "\"data\""},
               {:punctuation, ","},
               {:whitespace, " "},
               {:name, "key2"},
               {:punctuation, ":"},
               {:whitespace, " "},
               {:string_double, "\"data2\""},
               {:whitespace, " "},
               {:punctuation, "}"},
               {:punctuation, ";"},
               {:whitespace, "\n"}
             ]
    end
  end

  describe "match groups" do
    test "parentheses, brackets, braces" do
      assert [
               {:name_function, _, "foo"},
               {:punctuation, %{group_id: first}, "("},
               {:punctuation, %{group_id: second}, "{"},
               {:whitespace, _, " "},
               {:name, _, "bar"},
               {:punctuation, _, ","},
               {:whitespace, _, " "},
               {:punctuation, %{group_id: third}, "["},
               {:name, _, "baz"},
               {:punctuation, %{group_id: third}, "]"},
               {:whitespace, _, " "},
               {:punctuation, %{group_id: second}, "}"},
               {:punctuation, %{group_id: first}, ")"}
             ] = JavascriptLexer.lex("foo({ bar, [baz] })")
    end

    test "template interpolation" do
      assert [
               {:name, _, "hello"},
               {:whitespace, _, " "},
               {:operator, _, "="},
               {:whitespace, _, " "},
               {:string_backtick, _, ["`", 119, 111, 114, 108, 100, 32]},
               {:string_interpol, %{group_id: first}, "${"},
               {:punctuation, %{group_id: second}, "{"},
               {:name, _, "foo"},
               {:operator, _, ":"},
               {:whitespace, _, " "},
               {:punctuation, %{group_id: third}, "["},
               {:punctuation, %{group_id: third}, "]"},
               {:punctuation, %{group_id: second}, "}"},
               {:string_interpol, %{group_id: first}, "}"},
               {:string_backtick, _, ["`"]}
             ] = JavascriptLexer.lex("hello = `world ${{foo: []}}`")
    end
  end
end
