defmodule TypsterWeb.EditorLiveTest do
  use TypsterWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Typster.ProjectsFixtures

  setup %{conn: conn} do
    user = Typster.AccountsFixtures.user_fixture()
    conn = log_in_user(conn, user)
    project = project_fixture(user, %{name: "Quarterly Report"})
    %{conn: conn, user: user, project: project}
  end

  defp open_editor(conn, project) do
    {:ok, view, _html} = live(conn, ~p"/projects/#{project.id}/edit")
    view
  end

  test "the new-file button reveals an inline draft row", %{conn: conn, project: project} do
    view = open_editor(conn, project)

    refute has_element?(view, "#new-file-draft")
    view |> element("#create-main-file-button") |> render_click()
    assert has_element?(view, "#new-file-draft #new-file-form")
  end

  test "typing a plain name suggests the project's majority source extension",
       %{conn: conn, user: user, project: project} do
    file_fixture(project, user, %{path: "main.typ"})
    view = open_editor(conn, project)

    view |> element("#create-main-file-button") |> render_click()
    html = view |> form("#new-file-form", %{path: "conclusion"}) |> render_change()

    # The "+ .typ" hint pill is shown, no explicit extension chips for a single suggestion.
    assert html =~ "+ .typ"
    refute has_element?(view, ".ts-suggest")
  end

  test "a bib-like name with no existing .bib offers a .bib chip plus the majority type",
       %{conn: conn, user: user, project: project} do
    file_fixture(project, user, %{path: "main.typ"})
    view = open_editor(conn, project)

    view |> element("#create-main-file-button") |> render_click()
    view |> form("#new-file-form", %{path: "refs"}) |> render_change()

    assert has_element?(view, ".ts-suggest__chip", "refs.bib")
    assert has_element?(view, ".ts-suggest__chip", "refs.typ")
  end

  test "creating from the typed name resolves the smart extension and opens the file",
       %{conn: conn, user: user, project: project} do
    file_fixture(project, user, %{path: "main.typ"})
    view = open_editor(conn, project)

    view |> element("#create-main-file-button") |> render_click()
    view |> form("#new-file-form", %{path: "appendix"}) |> render_submit()

    assert path_exists?(user, project, "appendix.typ")
  end

  test "the default extension suggestion is a clickable button that creates the file",
       %{conn: conn, user: user, project: project} do
    file_fixture(project, user, %{path: "main.typ"})
    view = open_editor(conn, project)

    view |> element("#create-main-file-button") |> render_click()
    view |> form("#new-file-form", %{path: "conclusion"}) |> render_change()

    # The hint pill is a real button wired to create the resolved file.
    assert view |> element("button.ts-exthint[phx-value-path='conclusion.typ']") |> has_element?()
    view |> element("button.ts-exthint") |> render_click()

    assert path_exists?(user, project, "conclusion.typ")
  end

  test "clicking a bib suggestion chip creates that file",
       %{conn: conn, user: user, project: project} do
    file_fixture(project, user, %{path: "main.typ"})
    view = open_editor(conn, project)

    view |> element("#create-main-file-button") |> render_click()
    view |> form("#new-file-form", %{path: "refs"}) |> render_change()
    view |> element(".ts-suggest__chip[phx-value-path='refs.bib']") |> render_click()

    assert path_exists?(user, project, "refs.bib")
  end

  test "creating a duplicate path is rejected and keeps the draft open",
       %{conn: conn, user: user, project: project} do
    file_fixture(project, user, %{path: "main.typ"})
    view = open_editor(conn, project)

    view |> element("#create-main-file-button") |> render_click()
    html = view |> form("#new-file-form", %{path: "main.typ"}) |> render_submit()

    assert html =~ "already exists"
    assert has_element?(view, "#new-file-draft")
    # No duplicate row was inserted.
    scope = Typster.Accounts.Scope.for_user(user)
    tree = Typster.Files.get_file_tree(scope, project.id)
    assert Enum.count(tree, &(&1.path == "main.typ")) == 1
  end

  test "pinning a file moves it into the Pinned section", %{
    conn: conn,
    user: user,
    project: project
  } do
    file = file_fixture(project, user, %{path: "main.typ"})
    view = open_editor(conn, project)

    refute has_element?(view, ".ts-side__head--sub")

    view
    |> element("button[phx-click='toggle_pin'][phx-value-id='#{file.id}']")
    |> render_click()

    assert has_element?(view, ".ts-side__head--sub", "Pinned")
    assert has_element?(view, ".ts-tree__pin-ind")

    scope = Typster.Accounts.Scope.for_user(user)
    assert Typster.Files.get_file!(scope, file.id).pinned
  end

  test "deleting a file removes it from the tree", %{conn: conn, user: user, project: project} do
    file_fixture(project, user, %{path: "main.typ"})
    other = file_fixture(project, user, %{path: "notes.md"})
    view = open_editor(conn, project)

    assert has_element?(view, "[phx-value-file-id='#{other.id}']")

    view
    |> element("button[phx-click='delete_file'][phx-value-id='#{other.id}']")
    |> render_click()

    refute path_exists?(user, project, "notes.md")
    assert path_exists?(user, project, "main.typ")
  end

  test "opening files adds tabs and closing a tab activates a neighbor",
       %{conn: conn, user: user, project: project} do
    file_fixture(project, user, %{path: "main.typ"})
    other = file_fixture(project, user, %{path: "sections/intro.typ"})
    view = open_editor(conn, project)

    # main.typ opens as the initial tab; open the second file.
    view
    |> element("[phx-click='select_file'][phx-value-file-id='#{other.id}']")
    |> render_click()

    assert view |> element(".ts-tab.is-active .ts-tab__label") |> render() =~ "intro.typ"

    # Two tabs now open.
    assert view |> render() |> then(&(Regex.scan(~r/ts-tab__label/, &1) |> length())) == 2

    # Close the active tab → falls back to the remaining one.
    view |> element(".ts-tab.is-active .ts-tab__close") |> render_click()
    assert view |> element(".ts-tab.is-active .ts-tab__label") |> render() =~ "main.typ"
  end

  test "new file is seeded into the folder of the active file",
       %{conn: conn, user: user, project: project} do
    file_fixture(project, user, %{path: "sections/intro.typ"})
    view = open_editor(conn, project)

    # sections/intro.typ is the initial file, so its folder is active.
    view |> element("#create-main-file-button") |> render_click()

    # The folder is shown as a static prefix; you type only the filename.
    assert has_element?(view, ".ts-draft__dir", "sections/")
    view |> form("#new-file-form", %{path: "results"}) |> render_submit()
    assert path_exists?(user, project, "sections/results.typ")
  end

  test "the header breadcrumb shows the active file's path segments",
       %{conn: conn, user: user, project: project} do
    file_fixture(project, user, %{path: "sections/intro.typ"})
    view = open_editor(conn, project)

    assert has_element?(view, ".ts-crumb .ts-crumb__seg", "sections")
    assert has_element?(view, ".ts-crumb .ts-crumb__seg.is-active", "intro.typ")
  end

  test "outline numbers headings and shows a section count",
       %{conn: conn, user: user, project: project} do
    file_fixture(project, user, %{path: "main.typ"})
    view = open_editor(conn, project)

    render_hook(view, "outline_parsed", %{
      "items" => [
        %{"level" => 1, "text" => "Quarterly Report", "line" => 1},
        %{"level" => 2, "text" => "Summary", "line" => 3},
        %{"level" => 2, "text" => "Key results", "line" => 7},
        %{"level" => 3, "text" => "Uptime", "line" => 9}
      ]
    })

    # level-1 title stays unnumbered; level 2 -> 1, 2; level 3 -> 2.1
    assert has_element?(view, ".ts-outline__num", "2.1")
    assert has_element?(view, ".ts-side__count", "4 sections")
  end

  test "the new-folder button creates a folder seeded with a starter file",
       %{conn: conn, user: user, project: project} do
    file_fixture(project, user, %{path: "main.typ"})
    view = open_editor(conn, project)

    view |> element("#create-folder-button") |> render_click()
    assert has_element?(view, "#new-file-draft #new-file-form")
    view |> form("#new-file-form", %{path: "chapters"}) |> render_submit()

    assert path_exists?(user, project, "chapters/untitled.typ")
  end

  test "dropping a source file onto the editor creates it from the dropped content",
       %{conn: conn, user: user, project: project} do
    file_fixture(project, user, %{path: "main.typ"})
    view = open_editor(conn, project)

    input =
      file_input(view, "#dropped-upload-form", :dropped, [
        %{name: "dropped.typ", content: "= Dropped in", type: "text/plain"}
      ])

    render_upload(input, "dropped.typ")

    scope = Typster.Accounts.Scope.for_user(user)

    created =
      Enum.find(Typster.Files.get_file_tree(scope, project.id), &(&1.path == "dropped.typ"))

    assert created.content == "= Dropped in"
  end

  test "using a template stages its content into the file you create",
       %{conn: conn, user: user, project: project} do
    scope = Typster.Accounts.Scope.for_user(user)

    {:ok, tpl} =
      Typster.Templates.create_template(scope, %{name: "ieee.typ", content: "= From tpl"})

    file_fixture(project, user, %{path: "main.typ"})
    view = open_editor(conn, project)

    view
    |> element("button[phx-click='use_template'][phx-value-id='#{tpl.id}']")
    |> render_click()

    assert has_element?(view, "#new-file-draft")
    view |> form("#new-file-form", %{path: "paper.typ"}) |> render_submit()

    created = Enum.find(Typster.Files.get_file_tree(scope, project.id), &(&1.path == "paper.typ"))
    assert created.content == "= From tpl"
  end

  test "file rows render colored type chips by extension",
       %{conn: conn, user: user, project: project} do
    file_fixture(project, user, %{path: "main.typ"})
    file_fixture(project, user, %{path: "refs.bib"})
    view = open_editor(conn, project)

    assert has_element?(view, ".ts-filechip--typ")
    assert has_element?(view, ".ts-filechip--bib")
  end

  defp path_exists?(user, project, path) do
    scope = Typster.Accounts.Scope.for_user(user)
    Enum.any?(Typster.Files.get_file_tree(scope, project.id), &(&1.path == path))
  end
end
