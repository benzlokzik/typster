defmodule TypsterWeb.InviteControllerTest do
  use TypsterWeb.ConnCase, async: true

  import Typster.AccountsFixtures, only: [user_scope_fixture: 0]
  import Typster.ProjectsFixtures, only: [project_fixture: 1]

  alias Typster.Sharing

  defp invite(context) do
    owner = user_scope_fixture()
    project = project_fixture(owner)
    # Invites are now bound to the invited email, so address it to the logged-in
    # user when there is one (authenticated cases); fall back to a guest address
    # for the unauthenticated case, which never reaches acceptance anyway.
    email = (context[:user] && context.user.email) || "guest@example.com"
    {:ok, collab} = Sharing.invite_collaborator(owner, project.id, email, :viewer)
    %{project: project, collab: collab}
  end

  describe "GET /invites/:id while unauthenticated" do
    setup :invite

    test "bounces to log-in and remembers the invite path", %{conn: conn, collab: collab} do
      conn = get(conn, ~p"/invites/#{collab.id}")

      assert redirected_to(conn) == ~p"/users/log-in"
      assert get_session(conn, :user_return_to) == "/invites/#{collab.id}"
    end
  end

  describe "GET /invites/:id while authenticated" do
    setup [:register_and_log_in_user, :invite]

    test "accepts the invite and redirects to the editor", %{
      conn: conn,
      user: user,
      collab: collab,
      project: project
    } do
      conn = get(conn, ~p"/invites/#{collab.id}")

      assert redirected_to(conn) == ~p"/projects/#{project.id}/edit"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "welcome"

      accepted = Typster.Repo.get!(Typster.Sharing.Collaborator, collab.id)
      assert accepted.status == :accepted
      assert accepted.user_id == user.id
    end

    test "redirects to projects with an error for an unknown invite", %{conn: conn} do
      conn = get(conn, ~p"/invites/#{Ecto.UUID.generate()}")

      assert redirected_to(conn) == ~p"/projects"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "invalid"
    end

    test "redirects to projects with an error for a malformed id", %{conn: conn} do
      conn = get(conn, ~p"/invites/not-a-uuid")

      assert redirected_to(conn) == ~p"/projects"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "invalid"
    end
  end
end
