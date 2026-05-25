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

    scope = Typster.Accounts.Scope.for_user(user)
    tree = Typster.Files.get_file_tree(scope, project.id)
    assert Enum.any?(tree, &(&1.path == "appendix.typ"))
  end
end
