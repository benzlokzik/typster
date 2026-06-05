defmodule TypsterWeb.AnalyticsPanelProTest do
  @moduledoc """
  Proves the Pro-only analytics panel — whose HEEx markup lives in the closed
  `Typster.Pro.Analytics.Components` — actually renders in the host's share modal
  for an entitled owner. `:pro`-tagged: the component (and the entitlement that
  unlocks the panel) only exist in the Pro edition.
  """
  use TypsterWeb.ConnCase, async: true

  @moduletag :pro

  import Phoenix.LiveViewTest
  import Typster.AccountsFixtures, only: [pro_user_fixture: 0]
  import Typster.ProjectsFixtures, only: [project_fixture: 1, file_fixture: 3]

  test "renders the Pro analytics panel (HEEx from the Pro repo) for a Pro owner", %{conn: conn} do
    owner = pro_user_fixture()
    conn = log_in_user(conn, owner)
    project = project_fixture(owner)
    file_fixture(project, owner, %{path: "main.typ"})

    {:ok, view, _html} = live(conn, ~p"/projects/#{project.id}/edit")

    view |> element(".ts-tb__share") |> render_click()
    view |> element(".share-tabs button[phx-value-tab=\"link\"]") |> render_click()

    # The panel, its stats, and its sparkline are all markup defined in the Pro
    # component — their presence here proves the closed HEEx rendered in the host.
    assert has_element?(view, ".share-analytics")
    assert has_element?(view, ".share-analytics .label")
    assert has_element?(view, ".share-analytics__stat .n")
    assert has_element?(view, ".share-analytics__spark .bar")
  end
end
