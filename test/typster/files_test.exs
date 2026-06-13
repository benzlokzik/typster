defmodule Typster.FilesTest do
  use Typster.DataCase, async: true

  import Typster.ProjectsFixtures

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

  describe "create_file/3 path uniqueness" do
    setup do
      user = Typster.AccountsFixtures.user_fixture()
      %{scope: Typster.Accounts.Scope.for_user(user), project: project_fixture(user)}
    end

    test "rejects a second file with the same path in the same project", %{
      scope: scope,
      project: project
    } do
      assert {:ok, _} = Files.create_file(scope, project.id, %{path: "main.typ", content: ""})
      assert {:error, changeset} = Files.create_file(scope, project.id, %{path: "main.typ"})
      assert %{path: ["already exists in this project"]} = errors_on(changeset)
    end

    test "allows the same path in a different project", %{scope: scope, project: project} do
      other = project_fixture(scope)
      assert {:ok, _} = Files.create_file(scope, project.id, %{path: "main.typ"})
      assert {:ok, _} = Files.create_file(scope, other.id, %{path: "main.typ"})
    end
  end

  describe "create_file/3 path validation" do
    setup do
      user = Typster.AccountsFixtures.user_fixture()
      %{scope: Typster.Accounts.Scope.for_user(user), project: project_fixture(user)}
    end

    test "rejects traversal, absolute, backslash, and empty-segment paths", %{
      scope: scope,
      project: project
    } do
      bad_paths = [
        "../evil.typ",
        "a/../b.typ",
        "./x.typ",
        "/etc/x.typ",
        "a\\b.typ",
        "a//b.typ",
        "a/ /b.typ"
      ]

      for bad <- bad_paths do
        assert {:error, changeset} = Files.create_file(scope, project.id, %{path: bad})
        assert %{path: [_ | _]} = errors_on(changeset)
      end
    end

    test "accepts normal nested relative paths", %{scope: scope, project: project} do
      assert {:ok, _} = Files.create_file(scope, project.id, %{path: "chapters/01-intro.typ"})
      assert {:ok, _} = Files.create_file(scope, project.id, %{path: "refs.bib"})
    end

    test "update_file/3 enforces the same path rules", %{scope: scope, project: project} do
      {:ok, file} = Files.create_file(scope, project.id, %{path: "ok.typ"})
      assert {:error, changeset} = Files.update_file(scope, file, %{path: "../../etc/evil.typ"})
      assert %{path: [_ | _]} = errors_on(changeset)
    end
  end

  describe "create_file/3 parent scoping" do
    setup do
      user = Typster.AccountsFixtures.user_fixture()
      %{scope: Typster.Accounts.Scope.for_user(user), project: project_fixture(user)}
    end

    test "accepts a parent from the same project", %{scope: scope, project: project} do
      {:ok, parent} = Files.create_file(scope, project.id, %{path: "sections/intro.typ"})

      assert {:ok, _} =
               Files.create_file(scope, project.id, %{
                 path: "sections/body.typ",
                 parent_id: parent.id
               })
    end

    test "rejects a parent from another project (cross-project linking)", %{
      scope: scope,
      project: project
    } do
      other = project_fixture(scope)
      {:ok, foreign_parent} = Files.create_file(scope, other.id, %{path: "main.typ"})

      assert {:error, changeset} =
               Files.create_file(scope, project.id, %{path: "x.typ", parent_id: foreign_parent.id})

      assert %{parent_id: ["does not belong to this project"]} = errors_on(changeset)
    end

    test "rejects a parent owned by a different user (cross-tenant linking)", %{
      scope: scope,
      project: project
    } do
      other_user = Typster.AccountsFixtures.user_fixture()
      other_scope = Typster.Accounts.Scope.for_user(other_user)
      other_project = project_fixture(other_user)
      {:ok, foreign} = Files.create_file(other_scope, other_project.id, %{path: "main.typ"})

      assert {:error, changeset} =
               Files.create_file(scope, project.id, %{path: "x.typ", parent_id: foreign.id})

      assert %{parent_id: ["does not belong to this project"]} = errors_on(changeset)
    end
  end

  describe "set_pinned/3" do
    setup do
      user = Typster.AccountsFixtures.user_fixture()
      %{scope: Typster.Accounts.Scope.for_user(user), project: project_fixture(user)}
    end

    test "toggles the pinned flag and persists it", %{scope: scope, project: project} do
      {:ok, file} = Files.create_file(scope, project.id, %{path: "main.typ"})
      refute file.pinned

      assert {:ok, pinned} = Files.set_pinned(scope, file, true)
      assert pinned.pinned
      assert Files.get_file!(scope, file.id).pinned

      assert {:ok, unpinned} = Files.set_pinned(scope, file, false)
      refute unpinned.pinned
    end
  end

  describe "accepted collaborators can read and write files" do
    setup do
      owner = Typster.AccountsFixtures.user_scope_fixture()
      project = project_fixture(owner)

      member =
        Typster.Accounts.Scope.for_user(
          Typster.AccountsFixtures.user_fixture(%{email: "g@example.com"})
        )

      {:ok, invite} =
        Typster.Sharing.invite_collaborator(owner, project.id, "g@example.com", :editor)

      %{owner: owner, project: project, member: member, invite: invite}
    end

    test "a pending invitee has no file access yet", %{member: member, project: project} do
      assert_raise Ecto.NoResultsError, fn -> Files.get_file_tree(member, project.id) end

      assert_raise Ecto.NoResultsError, fn ->
        Files.create_file(member, project.id, %{path: "main.typ"})
      end
    end

    test "an accepted collaborator can create, read, and update files", ctx do
      %{owner: owner, project: project, member: member, invite: invite} = ctx
      {:ok, file} = Files.create_file(owner, project.id, %{path: "main.typ", content: "= Hi"})
      {:ok, _} = Typster.Sharing.accept_invite(member, invite.id)

      assert [_ | _] = Files.get_file_tree(member, project.id)
      assert Files.get_file!(member, file.id).id == file.id
      assert {:ok, saved} = Files.update_file_content(member, file, "= Edited by collaborator")
      assert saved.content == "= Edited by collaborator"

      assert {:ok, made} = Files.create_file(member, project.id, %{path: "chapter.typ"})
      assert made.project_id == project.id
    end
  end
end
