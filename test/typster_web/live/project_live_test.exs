defmodule TypsterWeb.ProjectLiveTest do
  use TypsterWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Typster.ProjectsFixtures

  test "projects routes redirect when unauthenticated", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/projects")
  end

  test "project index only shows the current user's projects", %{conn: conn} do
    user = conn.assigns[:user] || Typster.AccountsFixtures.user_fixture()
    other_user = Typster.AccountsFixtures.user_fixture()
    conn = log_in_user(conn, user)

    project_fixture(user, %{name: "Visible Project"})
    project_fixture(other_user, %{name: "Hidden Project"})

    {:ok, _view, html} = live(conn, ~p"/projects")

    assert html =~ "Visible Project"
    refute html =~ "Hidden Project"
  end

  test "editor prefers main.typ as the selected file", %{conn: conn} do
    user = Typster.AccountsFixtures.user_fixture()
    conn = log_in_user(conn, user)
    project = project_fixture(user)
    main_file = file_fixture(project, user, %{path: "main.typ", content: "= Main"})
    _other_file = file_fixture(project, user, %{path: "appendix.typ", content: "= Appendix"})

    {:ok, view, _html} = live(conn, ~p"/projects/#{project.id}/edit")

    assert has_element?(view, "#editor-container[data-file-id=\"#{main_file.id}\"]")
  end

  test "show page lists uploaded assets", %{conn: conn} do
    user = Typster.AccountsFixtures.user_fixture()
    conn = log_in_user(conn, user)
    project = project_fixture(user)
    _asset = asset_fixture(project, user, %{filename: "diagram.png"})

    {:ok, view, _html} = live(conn, ~p"/projects/#{project.id}")

    assert has_element?(view, "#project-files")
    assert has_element?(view, "#project-files li", "diagram.png")
  end
end
