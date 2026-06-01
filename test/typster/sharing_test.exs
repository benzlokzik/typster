defmodule Typster.SharingTest do
  use Typster.DataCase, async: true

  import Swoosh.TestAssertions
  import Typster.AccountsFixtures, only: [user_scope_fixture: 0]
  import Typster.ProjectsFixtures, only: [project_fixture: 1]

  alias Typster.Sharing
  alias Typster.Sharing.Collaborator
  alias Typster.Sharing.ShareLink

  setup do
    scope = user_scope_fixture()
    project = project_fixture(scope)
    # Drain the confirmation/login emails emitted while building the user
    # fixture so each test asserts only against its own sent emails.
    flush_emails()
    %{scope: scope, project: project}
  end

  # Removes any pending `{:email, _}` messages from the test process inbox.
  defp flush_emails do
    receive do
      {:email, _} -> flush_emails()
    after
      0 -> :ok
    end
  end

  describe "get_or_create_link/2" do
    test "creates a link with a token and default read scope", %{scope: scope, project: project} do
      link = Sharing.get_or_create_link(scope, project.id)

      assert %ShareLink{} = link
      assert link.project_id == project.id
      assert link.scope == :read
      assert link.allow_download == true
      assert is_binary(link.token) and link.token != ""
      assert link.token =~ ~r/^[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}$/
    end

    test "is idempotent: returns the same link on repeat calls", %{
      scope: scope,
      project: project
    } do
      first = Sharing.get_or_create_link(scope, project.id)
      second = Sharing.get_or_create_link(scope, project.id)

      assert first.id == second.id
      assert first.token == second.token
    end

    test "raises when the scope does not own the project", %{project: project} do
      other = user_scope_fixture()

      assert_raise Ecto.NoResultsError, fn ->
        Sharing.get_or_create_link(other, project.id)
      end
    end
  end

  describe "update_link/3" do
    test "changes the link scope and allow_download", %{scope: scope, project: project} do
      link = Sharing.get_or_create_link(scope, project.id)

      assert {:ok, updated} =
               Sharing.update_link(scope, link, %{scope: :full, allow_download: false})

      assert updated.scope == :full
      assert updated.allow_download == false
    end

    test "raises when the scope does not own the project", %{scope: scope, project: project} do
      link = Sharing.get_or_create_link(scope, project.id)
      other = user_scope_fixture()

      assert_raise Ecto.NoResultsError, fn ->
        Sharing.update_link(other, link, %{scope: :full})
      end
    end
  end

  describe "rotate_link/2" do
    test "generates a new token", %{scope: scope, project: project} do
      link = Sharing.get_or_create_link(scope, project.id)

      assert {:ok, rotated} = Sharing.rotate_link(scope, link)
      assert rotated.token != link.token
      assert rotated.token =~ ~r/^[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}$/
    end

    test "raises when the scope does not own the project", %{scope: scope, project: project} do
      link = Sharing.get_or_create_link(scope, project.id)
      other = user_scope_fixture()

      assert_raise Ecto.NoResultsError, fn ->
        Sharing.rotate_link(other, link)
      end
    end
  end

  describe "get_link_by_token/1 (public)" do
    test "resolves a created link and preloads the project", %{scope: scope, project: project} do
      link = Sharing.get_or_create_link(scope, project.id)

      resolved = Sharing.get_link_by_token(link.token)

      assert %ShareLink{} = resolved
      assert resolved.id == link.id
      assert resolved.project.id == project.id
    end

    test "returns nil for an unknown token" do
      assert Sharing.get_link_by_token("zzzz-zzzz-zzzz") == nil
    end

    test "returns nil for a blank or non-binary token" do
      assert Sharing.get_link_by_token("") == nil
      assert Sharing.get_link_by_token("   ") == nil
      assert Sharing.get_link_by_token(nil) == nil
    end
  end

  describe "invite_collaborator/4" do
    test "creates a pending collaborator and sends an email", %{scope: scope, project: project} do
      assert {:ok, %Collaborator{} = collab} =
               Sharing.invite_collaborator(scope, project.id, "friend@example.com", :editor)

      assert collab.email == "friend@example.com"
      assert collab.role == :editor
      assert collab.status == :pending
      assert collab.project_id == project.id

      assert_received {:email, %Swoosh.Email{} = email}
      assert {"", "friend@example.com"} in email.to
      assert email.subject =~ project.name
      assert email.text_body =~ project.name
    end

    test "defaults the role to viewer", %{scope: scope, project: project} do
      assert {:ok, collab} =
               Sharing.invite_collaborator(scope, project.id, "viewer@example.com")

      assert collab.role == :viewer
    end

    test "returns an error changeset for an invalid email", %{scope: scope, project: project} do
      assert {:error, changeset} =
               Sharing.invite_collaborator(scope, project.id, "not-an-email", :viewer)

      refute changeset.valid?
      assert "must have the @ sign and no spaces" in errors_on(changeset).email
      assert_no_email_sent()
    end

    test "rejects a duplicate email for the same project", %{scope: scope, project: project} do
      assert {:ok, _} =
               Sharing.invite_collaborator(scope, project.id, "dupe@example.com", :viewer)

      assert {:error, changeset} =
               Sharing.invite_collaborator(scope, project.id, "dupe@example.com", :viewer)

      refute changeset.valid?

      errors = errors_on(changeset)

      assert "is already a collaborator on this project" in (errors[:email] || errors[:project_id])
    end

    test "raises when the scope does not own the project", %{project: project} do
      other = user_scope_fixture()

      assert_raise Ecto.NoResultsError, fn ->
        Sharing.invite_collaborator(other, project.id, "x@example.com", :viewer)
      end
    end
  end

  describe "list_collaborators/2, update_collaborator_role/3, remove_collaborator/2" do
    test "lists collaborators for the project", %{scope: scope, project: project} do
      {:ok, a} = Sharing.invite_collaborator(scope, project.id, "a@example.com", :viewer)
      {:ok, b} = Sharing.invite_collaborator(scope, project.id, "b@example.com", :editor)

      ids = scope |> Sharing.list_collaborators(project.id) |> Enum.map(& &1.id)
      assert a.id in ids
      assert b.id in ids
      assert length(ids) == 2
    end

    test "updates a collaborator role", %{scope: scope, project: project} do
      {:ok, collab} = Sharing.invite_collaborator(scope, project.id, "c@example.com", :viewer)

      assert {:ok, updated} = Sharing.update_collaborator_role(scope, collab, :editor)
      assert updated.role == :editor
    end

    test "removes a collaborator", %{scope: scope, project: project} do
      {:ok, collab} = Sharing.invite_collaborator(scope, project.id, "d@example.com", :viewer)

      assert {:ok, _} = Sharing.remove_collaborator(scope, collab)
      assert Sharing.list_collaborators(scope, project.id) == []
    end

    test "raises when a non-owner lists, updates, or removes", %{scope: scope, project: project} do
      {:ok, collab} = Sharing.invite_collaborator(scope, project.id, "e@example.com", :viewer)
      other = user_scope_fixture()

      assert_raise Ecto.NoResultsError, fn ->
        Sharing.list_collaborators(other, project.id)
      end

      assert_raise Ecto.NoResultsError, fn ->
        Sharing.update_collaborator_role(other, collab, :editor)
      end

      assert_raise Ecto.NoResultsError, fn ->
        Sharing.remove_collaborator(other, collab)
      end
    end
  end

  describe "changesets for forms" do
    test "change_link/1 returns a changeset" do
      assert %Ecto.Changeset{} = Sharing.change_link(%ShareLink{})
    end

    test "change_collaborator/2 returns a changeset" do
      assert %Ecto.Changeset{} = Sharing.change_collaborator(%Collaborator{})
    end
  end
end
