defmodule TypsterWeb.SharedProjectLiveTest do
  use TypsterWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Typster.ProjectsFixtures

  alias Typster.Accounts.Scope
  alias Typster.Sharing

  setup do
    owner = Typster.AccountsFixtures.user_fixture()
    scope = Scope.for_user(owner)
    project = project_fixture(owner)
    file_fixture(project, owner, %{path: "main.typ", content: "= Hi"})
    link = Sharing.get_or_create_link(scope, project.id)

    %{owner: owner, scope: scope, project: project, link: link}
  end

  describe ":read scope via /p" do
    test "renders the split read-only comp with source, preview and chrome", %{
      conn: conn,
      project: project,
      link: link
    } do
      {:ok, view, _html} = live(conn, ~p"/p/shared?#{[key: link.token]}")

      # Split layout (source + preview side by side).
      assert has_element?(view, ".embed-comp.embed-comp--split")
      # Read-only CodeMirror source pane is shown.
      assert has_element?(view, ".embed-source #editor-container")
      # Live preview pane.
      assert has_element?(view, ".embed-preview #preview-container")
      # Top bar shows the project name and the read-only pill.
      assert has_element?(view, ".embed-bar .slug", project.name)
      assert has_element?(view, ".ro-pill")
      # Open-in-Typster CTA in the footer.
      assert has_element?(view, ".embed-foot__cta")
    end
  end

  describe ":output scope via /p" do
    test "hides the source pane but keeps the preview", %{
      conn: conn,
      scope: scope,
      link: link
    } do
      {:ok, _link} = Sharing.update_link(scope, link, %{scope: :output})

      {:ok, view, _html} = live(conn, ~p"/p/shared?#{[key: link.token]}")

      # Not a split layout when the source is hidden.
      refute has_element?(view, ".embed-comp.embed-comp--split")
      # The visible source section is gone (only a hidden mirror remains).
      refute has_element?(view, ".embed-source #editor-container")
      # Preview is still rendered.
      assert has_element?(view, ".embed-preview #preview-container")
    end
  end

  describe "invalid link" do
    test "renders the invalid panel and no embed comp", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/p/shared?#{[key: "does-not-exist"]}")

      assert has_element?(view, ".share-public--invalid .share-public__panel")
      refute has_element?(view, ".embed-comp")
    end
  end

  describe "/embed/:token" do
    test "mounts the embed variant", %{conn: conn, link: link} do
      {:ok, view, _html} = live(conn, ~p"/embed/#{link.token}")

      assert has_element?(view, ".share-public--embed")
      assert has_element?(view, ".embed-comp")
    end
  end

  describe "read-only client hook events" do
    test "tolerates preview hook pushes without crashing", %{conn: conn, link: link} do
      {:ok, view, _html} = live(conn, ~p"/p/shared?#{[key: link.token]}")

      # The CodeMirror/Preview hooks push these editor events; the read-only
      # view must swallow them via its catch-all handle_event/3.
      render_hook(view, "update_preview", %{"ms" => 12, "pages" => 1})
      render_hook(view, "preview_error", %{"message" => "x", "errors" => 1})

      # If the catch-all clause were missing, the pushes above would have
      # crashed the LiveView and this assertion would fail.
      assert has_element?(view, ".embed-comp")
    end
  end
end
