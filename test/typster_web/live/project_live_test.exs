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

  test "project index renders the filter segments and a serif heading", %{conn: conn} do
    user = Typster.AccountsFixtures.user_fixture()
    conn = log_in_user(conn, user)

    {:ok, view, _html} = live(conn, ~p"/projects")

    assert has_element?(view, "h1 .ts-serif")
    assert has_element?(view, "#filter-all.is-active")
    assert has_element?(view, "#filter-recent")
    assert has_element?(view, "#filter-starred")
  end

  test "filtering to starred shows the empty state", %{conn: conn} do
    user = Typster.AccountsFixtures.user_fixture()
    conn = log_in_user(conn, user)
    project_fixture(user, %{name: "Visible Project"})

    {:ok, view, _html} = live(conn, ~p"/projects")
    assert render(view) =~ "Visible Project"

    view |> element("#filter-starred") |> render_click()

    refute render(view) =~ "Visible Project"
    assert has_element?(view, "#filter-starred.is-active")
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

  test "editor renders the format toolbar and opens the command palette", %{conn: conn} do
    user = Typster.AccountsFixtures.user_fixture()
    conn = log_in_user(conn, user)
    project = project_fixture(user)
    file_fixture(project, user, %{path: "main.typ", content: "= Main"})

    {:ok, view, _html} = live(conn, ~p"/projects/#{project.id}/edit")

    assert has_element?(view, "#editor-shell .ts-formatbar")
    assert has_element?(view, ".ts-preview__bar .ts-pill")
    refute has_element?(view, "#command-palette")

    view |> element("button.ts-tb__omni") |> render_click()

    assert has_element?(view, "#command-palette")
    assert has_element?(view, "#command-palette #palette-input")
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

  describe "projects shared with the current user" do
    setup %{conn: conn} do
      owner = Typster.AccountsFixtures.user_fixture()
      member = Typster.AccountsFixtures.user_fixture()
      owner_scope = Typster.Accounts.Scope.for_user(owner)
      shared = project_fixture(owner, %{name: "Shared With Me"})
      mine = project_fixture(member, %{name: "My Own Project"})
      # Invite the member by email only — no accept-link click. Visiting their
      # project list should be enough to surface it.
      {:ok, _} =
        Typster.Sharing.invite_collaborator(owner_scope, shared.id, member.email, :editor)

      %{conn: log_in_user(conn, member), shared: shared, mine: mine}
    end

    test "appears in the list, badged as Shared, after visiting /projects", %{
      conn: conn,
      shared: shared,
      mine: mine
    } do
      {:ok, view, _html} = live(conn, ~p"/projects")

      assert has_element?(view, "##{dom_id(shared)} .ts-list__title", "Shared With Me")
      assert has_element?(view, "##{dom_id(shared)} .ts-shared-badge")
      # The user's own project carries no Shared badge.
      assert has_element?(view, "##{dom_id(mine)} .ts-list__title", "My Own Project")
      refute has_element?(view, "##{dom_id(mine)} .ts-shared-badge")
    end

    test "offers no delete button on a project the user doesn't own", %{
      conn: conn,
      shared: shared,
      mine: mine
    } do
      {:ok, view, _html} = live(conn, ~p"/projects")

      refute has_element?(view, "#delete-project-#{shared.id}")
      assert has_element?(view, "#delete-project-#{mine.id}")
    end
  end

  # LiveView streams prefix the DOM id with the stream name (`projects-<id>`).
  defp dom_id(project), do: "projects-#{project.id}"
end
