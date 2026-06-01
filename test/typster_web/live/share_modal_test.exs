defmodule TypsterWeb.ShareModalTest do
  use TypsterWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Typster.ProjectsFixtures

  alias Typster.Accounts.Scope
  alias Typster.Sharing

  # The logged-in user OWNS the project (project_fixture/2 derives the scope from
  # the user), so the owner-only Share button and all share_* handlers are wired.
  setup :register_and_log_in_user

  setup %{conn: conn, user: user} do
    project = project_fixture(user, %{name: "Quarterly Report"})
    file_fixture(project, user, %{path: "main.typ"})
    %{conn: conn, user: user, project: project}
  end

  defp open_editor(conn, project) do
    {:ok, view, _html} = live(conn, ~p"/projects/#{project.id}/edit")
    view
  end

  defp open_share(conn, project) do
    view = open_editor(conn, project)
    view |> element(".ts-tb__share") |> render_click()
    view
  end

  defp scope_for(user), do: Scope.for_user(user)

  test "owner sees the Share button and opening it renders the modal",
       %{conn: conn, project: project} do
    view = open_editor(conn, project)

    assert has_element?(view, ".ts-tb__share")
    refute has_element?(view, "#share-modal")

    view |> element(".ts-tb__share") |> render_click()

    assert has_element?(view, ".share-overlay #share-modal")
  end

  test "share_tab switches to the Embed tab and shows the copy control",
       %{conn: conn, project: project} do
    view = open_share(conn, project)

    view |> element("button.tab[phx-value-tab='embed']") |> render_click()

    assert has_element?(view, "button.tab.active[phx-value-tab='embed']")
    assert has_element?(view, "#embed-copy")
  end

  test "share_scope on the Link tab sets the link scope to :output",
       %{conn: conn, user: user, project: project} do
    view = open_share(conn, project)

    view |> element("button.tab[phx-value-tab='link']") |> render_click()
    view |> element(".perm-card[phx-value-scope='output']") |> render_click()

    assert Sharing.get_or_create_link(scope_for(user), project.id).scope == :output
  end

  test "share_rotate generates a new token for the link",
       %{conn: conn, user: user, project: project} do
    scope = scope_for(user)
    token0 = Sharing.get_or_create_link(scope, project.id).token

    view = open_share(conn, project)
    view |> element("button.tab[phx-value-tab='link']") |> render_click()
    view |> element("button[phx-click='share_rotate']") |> render_click()

    assert Sharing.get_or_create_link(scope, project.id).token != token0
  end

  test "share_toggle_download flips the link's allow_download flag",
       %{conn: conn, user: user, project: project} do
    scope = scope_for(user)
    before = Sharing.get_or_create_link(scope, project.id).allow_download

    view = open_share(conn, project)
    view |> element("button.tab[phx-value-tab='link']") |> render_click()
    view |> element("[phx-click='share_toggle_download']") |> render_click()

    assert Sharing.get_or_create_link(scope, project.id).allow_download == not before
  end

  test "inviting a person adds a collaborator and shows the People badge count",
       %{conn: conn, user: user, project: project} do
    view = open_share(conn, project)
    view |> element("button.tab[phx-value-tab='people']") |> render_click()

    view
    |> form("#invite-form", %{"invite" => %{"email" => "x@example.com", "role" => "viewer"}})
    |> render_submit()

    collaborators = Sharing.list_collaborators(scope_for(user), project.id)
    assert [%{email: "x@example.com"}] = collaborators

    # The People tab badge reflects the single pending collaborator.
    assert has_element?(view, "button.tab[phx-value-tab='people'] .badge", "1")
  end

  test "share_remove_collab removes the invited collaborator",
       %{conn: conn, user: user, project: project} do
    scope = scope_for(user)

    view = open_share(conn, project)
    view |> element("button.tab[phx-value-tab='people']") |> render_click()

    view
    |> form("#invite-form", %{"invite" => %{"email" => "x@example.com", "role" => "viewer"}})
    |> render_submit()

    [collab] = Sharing.list_collaborators(scope, project.id)

    view
    |> element("[phx-click='share_remove_collab'][phx-value-id='#{collab.id}']")
    |> render_click()

    assert Sharing.list_collaborators(scope, project.id) == []
  end

  test "free plan locks the advanced link section and link activity stats",
       %{conn: conn, project: project} do
    view = open_share(conn, project)
    view |> element("button.tab[phx-value-tab='link']") |> render_click()

    assert has_element?(view, ".locked-section")
    assert has_element?(view, ".link-stats.locked-stats")
  end

  test "the Embed tab renders an iframe snippet pointing at the embed route",
       %{conn: conn, project: project} do
    view = open_share(conn, project)
    view |> element("button.tab[phx-value-tab='embed']") |> render_click()

    assert has_element?(view, "#embed-copy")
    assert view |> element("#share-modal pre") |> render() =~ "/embed/"
  end
end
