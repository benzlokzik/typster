defmodule Typster.SharingJoinTest do
  # async: false — these tests inject the :collaboration_impl override, which
  # is global application env (same trade-off as Typster.FeaturesTest).
  use Typster.DataCase, async: false

  import Typster.AccountsFixtures, only: [user_scope_fixture: 0, user_fixture: 1]
  import Typster.ProjectsFixtures

  alias Typster.Accounts.Scope
  alias Typster.Sharing
  alias Typster.Sharing.Collaborator

  # Stand-in for the private Typster.Pro.Collaboration: grants whenever the
  # link's open_edit flag is on, ignoring the owner's plan.
  defmodule OpenDoor do
    def open_edit?(_owner, %{open_edit: open_edit}), do: open_edit
  end

  setup do
    on_exit(fn -> Application.delete_env(:typster, :collaboration_impl) end)

    owner = user_scope_fixture()
    project = project_fixture(owner)
    file_fixture(project, owner, %{path: "main.typ", content: "= Hi"})
    link = Sharing.get_or_create_link(owner, project.id)

    %{owner: owner, project: project, link: link}
  end

  describe "fork_via_link/3" do
    test "clones the project for a stranger when allow_fork is on", %{
      owner: owner,
      project: project,
      link: link
    } do
      {:ok, link} = Sharing.update_link(owner, link, %{allow_fork: true})
      visitor = user_scope_fixture()

      assert {:ok, fork} = Sharing.fork_via_link(visitor, link.token, %{name: "Mine now"})
      assert fork.user_id == visitor.user.id
      assert fork.id != project.id
    end

    test "refuses while allow_fork is off (the default)", %{link: link} do
      visitor = user_scope_fixture()
      assert {:error, :forbidden} = Sharing.fork_via_link(visitor, link.token, %{name: "Nope"})
    end

    test "unknown tokens and anonymous visitors get :not_found", %{link: link} do
      visitor = user_scope_fixture()
      assert {:error, :not_found} = Sharing.fork_via_link(visitor, "xxxx-xxxx-xxxx", %{name: "?"})
      assert {:error, :not_found} = Sharing.fork_via_link(%Scope{user: nil}, link.token, %{})
    end
  end

  describe "join_via_link/2" do
    test "joins a stranger as an accepted editor and is idempotent", %{
      owner: owner,
      link: link
    } do
      {:ok, link} = Sharing.update_link(owner, link, %{open_edit: true})
      Application.put_env(:typster, :collaboration_impl, OpenDoor)
      visitor = user_scope_fixture()

      assert {:ok, %Collaborator{} = collab} = Sharing.join_via_link(visitor, link.token)
      assert collab.status == :accepted
      assert collab.role == :editor
      assert collab.user_id == visitor.user.id

      assert {:ok, %Collaborator{id: same_id}} = Sharing.join_via_link(visitor, link.token)
      assert same_id == collab.id
    end

    test "accepts a prior email invite in place, keeping its role", %{
      owner: owner,
      project: project,
      link: link
    } do
      {:ok, link} = Sharing.update_link(owner, link, %{open_edit: true})
      Application.put_env(:typster, :collaboration_impl, OpenDoor)

      email = "invitee#{System.unique_integer([:positive])}@example.com"
      {:ok, invite} = Sharing.invite_collaborator(owner, project.id, email, :viewer)
      visitor = Scope.for_user(user_fixture(%{email: email}))

      assert {:ok, %Collaborator{} = collab} = Sharing.join_via_link(visitor, link.token)
      assert collab.id == invite.id
      assert collab.status == :accepted
      assert collab.role == :viewer
      assert collab.user_id == visitor.user.id
    end

    test "the owner short-circuits without a collaborator row", %{owner: owner, link: link} do
      {:ok, link} = Sharing.update_link(owner, link, %{open_edit: true})
      Application.put_env(:typster, :collaboration_impl, OpenDoor)

      assert {:ok, :owner} = Sharing.join_via_link(owner, link.token)
      assert Sharing.list_collaborators(owner, link.project_id) == []
    end

    test "refuses while open_edit is off, even with a permissive impl", %{link: link} do
      Application.put_env(:typster, :collaboration_impl, OpenDoor)
      visitor = user_scope_fixture()

      assert {:error, :forbidden} = Sharing.join_via_link(visitor, link.token)
    end

    test "the community fallback denies even with open_edit on", %{owner: owner, link: link} do
      {:ok, link} = Sharing.update_link(owner, link, %{open_edit: true})
      Application.put_env(:typster, :collaboration_impl, Typster.Sharing.Collaboration.Free)
      visitor = user_scope_fixture()

      assert {:error, :forbidden} = Sharing.join_via_link(visitor, link.token)
    end
  end
end
