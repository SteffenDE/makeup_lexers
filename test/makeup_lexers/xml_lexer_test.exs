defmodule MakeupLexers.XMLLexerTest do
  use ExUnit.Case, async: true
  alias MakeupLexers.XMLLexer

  # Helper function to lex and return tokens without metadata
  defp lex(text) do
    text
    |> XMLLexer.lex()
    |> Enum.map(fn {type, _meta, value} -> {type, IO.iodata_to_binary([value])} end)
  end

  describe "XML declaration and processing instructions" do
    test "XML declaration" do
      assert lex("<?xml version=\"1.0\" encoding=\"UTF-8\"?>") == [
               {:comment_preproc, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"}
             ]
    end

    test "processing instruction" do
      assert lex("<?display-mode full-screen?>") == [
               {:comment_preproc, "<?display-mode full-screen?>"}
             ]
    end
  end

  describe "comments" do
    test "single line comment" do
      assert lex("<!-- Basic element with attributes -->") == [
               {:comment_multiline, "<!-- Basic element with attributes -->"}
             ]
    end

    test "multi line comment" do
      assert lex("<!-- Multiple\nlines\nof text -->") == [
               {:comment_multiline, "<!-- Multiple\nlines\nof text -->"}
             ]
    end
  end

  describe "CDATA sections" do
    test "CDATA with special characters" do
      assert lex("<![CDATA[A story about the American Dream & society in the 1920s]]>") == [
               {:comment_preproc,
                "<![CDATA[A story about the American Dream & society in the 1920s]]>"}
             ]
    end
  end

  describe "DOCTYPE declarations" do
    test "simple DOCTYPE" do
      assert lex("<!DOCTYPE html>") == [
               {:name_tag, "<!DOCTYPE"},
               {:whitespace, " "},
               {:name_class, "html"},
               {:text, ""},
               {:name_tag, ">"}
             ]
    end

    test "DOCTYPE with internal subset" do
      doctype = """
      <!DOCTYPE library [
        <!ELEMENT library (book+)>
      ]>
      """

      assert lex(doctype) == [
               {:name_tag, "<!DOCTYPE"},
               {:whitespace, " "},
               {:name_class, "library"},
               {:whitespace, " "},
               {:punctuation, "["},
               {:whitespace, "\n  "},
               {:punctuation, "<"},
               {:keyword, "!"},
               {:keyword, "ELEMENT"},
               {:text, " library (book+)"},
               {:punctuation, ">"},
               {:whitespace, "\n"},
               {:punctuation, "]"},
               {:name_tag, ">"},
               {:whitespace, "\n"}
             ]
    end

    test "full doctype" do
      assert lex("""
             <!DOCTYPE html PUBLIC
               "-//W3C//DTD XHTML Basic 1.1//EN"
               "http://www.w3.org/TR/xhtml-basic/xhtml-basic11.dtd">
             """) == [
               {:name_tag, "<!DOCTYPE"},
               {:whitespace, " "},
               {:name_class, "html"},
               {:whitespace, " "},
               {:text,
                "PUBLIC\n  \"-//W3C//DTD XHTML Basic 1.1//EN\"\n  \"http://www.w3.org/TR/xhtml-basic/xhtml-basic11.dtd\""},
               {:name_tag, ">"},
               {:whitespace, "\n"}
             ]
    end
  end

  describe "elements and attributes" do
    test "basic element with attributes" do
      assert lex(~s(<book id="b1" category="fiction">)) == [
               {:punctuation, "<"},
               {:name_tag, "book"},
               {:whitespace, " "},
               {:name_attribute, "id"},
               {:operator, "="},
               {:string, "\""},
               {:string, "b1"},
               {:string, "\""},
               {:whitespace, " "},
               {:name_attribute, "category"},
               {:operator, "="},
               {:string, "\""},
               {:string, "fiction"},
               {:string, "\""},
               {:punctuation, ">"}
             ]
    end

    test "self-closing element" do
      assert lex("<pub:published />") == [
               {:punctuation, "<"},
               {:name_tag, "pub:published"},
               {:whitespace, " "},
               {:punctuation, "/>"}
             ]
    end

    test "element with namespace" do
      assert lex("<lit:book>") == [
               {:punctuation, "<"},
               {:name_tag, "lit:book"},
               {:punctuation, ">"}
             ]
    end

    test "closing tag" do
      assert lex("</title>") == [
               {:punctuation, "</"},
               {:name_tag, "title"},
               {:punctuation, ">"}
             ]
    end
  end

  describe "entities" do
    test "predefined entities" do
      entities = "&lt; &gt; &amp; &apos; &quot;"
      result = lex(entities)

      assert result == [
               {:name_entity, "&lt;"},
               {:whitespace, " "},
               {:name_entity, "&gt;"},
               {:whitespace, " "},
               {:name_entity, "&amp;"},
               {:whitespace, " "},
               {:name_entity, "&apos;"},
               {:whitespace, " "},
               {:name_entity, "&quot;"}
             ]
    end
  end

  describe "complex elements" do
    test "element with mixed content" do
      mixed = """
      <description>
        A tale about a girl named <emphasis>Alice</emphasis> who falls down a rabbit hole.
      </description>
      """

      assert lex(mixed) == [
               {:punctuation, "<"},
               {:name_tag, "description"},
               {:punctuation, ">"},
               {:whitespace, "\n  "},
               {:text, "A tale about a girl named "},
               {:punctuation, "<"},
               {:name_tag, "emphasis"},
               {:punctuation, ">"},
               {:text, "Alice"},
               {:punctuation, "</"},
               {:name_tag, "emphasis"},
               {:punctuation, ">"},
               {:whitespace, " "},
               {:text, "who falls down a rabbit hole.\n"},
               {:punctuation, "</"},
               {:name_tag, "description"},
               {:punctuation, ">"},
               {:whitespace, "\n"}
             ]
    end
  end

  describe "namespace declarations" do
    test "multiple namespace declarations" do
      assert lex(
               ~s(<library xmlns:lit="http://example.com/literature" xmlns:pub="http://example.com/publishing">)
             ) == [
               {:punctuation, "<"},
               {:name_tag, "library"},
               {:whitespace, " "},
               {:name_attribute, "xmlns:lit"},
               {:operator, "="},
               {:string, "\""},
               {:string, "http://example.com/literature"},
               {:string, "\""},
               {:whitespace, " "},
               {:name_attribute, "xmlns:pub"},
               {:operator, "="},
               {:string, "\""},
               {:string, "http://example.com/publishing"},
               {:string, "\""},
               {:punctuation, ">"}
             ]
    end
  end

  describe "whitespace handling" do
    test "preserved whitespace" do
      assert lex("<title>    The    Raven    </title>") == [
               {:punctuation, "<"},
               {:name_tag, "title"},
               {:punctuation, ">"},
               {:whitespace, "    "},
               {:text, "The    Raven    "},
               {:punctuation, "</"},
               {:name_tag, "title"},
               {:punctuation, ">"}
             ]
    end
  end

  describe "match groups" do
    test "matching tags" do
      assert [
               {:punctuation, %{group_id: first}, "<"},
               {:name_tag, _, "book"},
               {:punctuation, %{group_id: first}, ">"},
               {:punctuation, %{group_id: second}, "<"},
               {:name_tag, _, "title"},
               {:punctuation, %{group_id: second}, ">"},
               {:text, _, "Test"},
               {:punctuation, %{group_id: third}, "</"},
               {:name_tag, _, "title"},
               {:punctuation, %{group_id: third}, ">"},
               {:punctuation, %{group_id: fourth}, "</"},
               {:name_tag, _, "book"},
               {:punctuation, %{group_id: fourth}, ">"}
             ] = XMLLexer.lex("<book><title>Test</title></book>")
    end
  end
end
