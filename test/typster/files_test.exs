defmodule Typster.FilesTest do
  use Typster.DataCase, async: true

  alias Typster.Files

  describe "file classification" do
    test "classifies editable file types" do
      assert Files.editable_file?("main.typ")
      assert Files.editable_file?("refs.bib")
      assert Files.typst_file?("main.typ")
      assert Files.bibtex_file?("refs.bib")
      assert Files.file_kind("main.typ") == :text
      assert Files.file_kind("refs.bib") == :text
      assert Files.editor_language("main.typ") == "typst"
      assert Files.editor_language("refs.bib") == "bibtex"
    end

    test "classifies asset and unknown file types" do
      assert Files.asset_file?("assets/logo.png")
      assert Files.asset_file?("assets/font.woff2")
      assert Files.file_kind("assets/logo.png") == :asset
      assert Files.file_kind("archive.bin") == :unknown
      refute Files.editable_file?("archive.bin")
    end
  end

  describe "majority_source_extension/1" do
    test "defaults to .typ for an empty or Typst-heavy project" do
      assert Files.majority_source_extension([]) == ".typ"
      assert Files.majority_source_extension(["main.typ", "intro.typ", "notes.md"]) == ".typ"
    end

    test "suggests .tex when LaTeX sources dominate" do
      assert Files.majority_source_extension(["main.tex", "appendix.tex", "intro.typ"]) == ".tex"
      assert Files.majority_source_extension(["doc.tex", "macros.sty", "thesis.cls"]) == ".tex"
    end

    test "ties favor Typst" do
      assert Files.majority_source_extension(["a.tex", "b.typ"]) == ".typ"
    end

    test "accepts File structs and maps, ignoring assets" do
      files = [%Typster.Projects.File{path: "main.tex"}, %{path: "logo.png"}]
      assert Files.majority_source_extension(files) == ".tex"
    end
  end

  describe "new_file_suggestions/2" do
    test "returns [] for empty input or an explicitly typed extension" do
      assert Files.new_file_suggestions(["main.typ"], "") == []
      assert Files.new_file_suggestions(["main.typ"], "  ") == []
      assert Files.new_file_suggestions(["main.typ"], "notes.md") == []
    end

    test "suggests the project's majority source type for a plain name" do
      assert Files.new_file_suggestions(["main.typ"], "conclusion") == ["conclusion.typ"]
      assert Files.new_file_suggestions(["main.tex", "a.tex"], "conclusion") == ["conclusion.tex"]
    end

    test "a bib-like name with no existing .bib offers .bib first, then majority type" do
      assert Files.new_file_suggestions(["main.typ"], "refs") == ["refs.bib", "refs.typ"]

      assert Files.new_file_suggestions(["main.typ"], "references") == [
               "references.bib",
               "references.typ"
             ]

      assert Files.new_file_suggestions(["main.tex", "a.tex"], "biblio") == [
               "biblio.bib",
               "biblio.tex"
             ]
    end

    test "a bib-like name only suggests the majority type once a .bib already exists" do
      assert Files.new_file_suggestions(["main.typ", "refs.bib"], "library") == ["library.typ"]
    end

    test "short fragments below the match threshold are not treated as bib names" do
      assert Files.new_file_suggestions(["main.typ"], "re") == ["re.typ"]
    end

    test "matches a bib name nested under a folder by its basename" do
      assert Files.new_file_suggestions(["main.typ"], "src/bibliography") ==
               ["src/bibliography.bib", "src/bibliography.typ"]
    end
  end

  describe "resolve_new_file_path/2" do
    test "keeps an explicitly typed extension" do
      assert Files.resolve_new_file_path(["main.typ"], "notes.md") == "notes.md"
      assert Files.resolve_new_file_path(["main.typ"], "refs.bib") == "refs.bib"
    end

    test "applies the first smart suggestion when no extension is typed" do
      assert Files.resolve_new_file_path(["main.typ"], "conclusion") == "conclusion.typ"
      assert Files.resolve_new_file_path(["main.tex", "a.tex"], "conclusion") == "conclusion.tex"
      assert Files.resolve_new_file_path(["main.typ"], "refs") == "refs.bib"
    end

    test "trims whitespace and handles empty input" do
      assert Files.resolve_new_file_path(["main.typ"], "  draft  ") == "draft.typ"
      assert Files.resolve_new_file_path(["main.typ"], "") == ""
    end
  end

  describe "has_bibliography?/1" do
    test "detects an existing .bib file" do
      refute Files.has_bibliography?(["main.typ", "notes.md"])
      assert Files.has_bibliography?(["main.typ", "refs.bib"])
    end
  end
end
