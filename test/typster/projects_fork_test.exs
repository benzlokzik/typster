defmodule Typster.ProjectsForkTest do
  use Typster.DataCase, async: true

  import Typster.AccountsFixtures, only: [user_scope_fixture: 0]
  import Typster.ProjectsFixtures

  alias Typster.Files
  alias Typster.Projects

  setup do
    owner = user_scope_fixture()
    project = project_fixture(owner)
    %{owner: owner, project: project}
  end

  describe "fork_project/3" do
    test "deep-copies files and re-links the hierarchy to the new owner", %{
      owner: owner,
      project: project
    } do
      dir = file_fixture(project, owner, %{path: "chapters", content: nil})

      child =
        file_fixture(project, owner, %{
          path: "chapters/one.typ",
          content: "= One",
          parent_id: dir.id
        })

      visitor = user_scope_fixture()
      assert {:ok, fork} = Projects.fork_project(visitor, project, %{name: "My copy"})

      assert fork.user_id == visitor.user.id
      assert fork.name == "My copy"

      copies = Files.get_file_tree(visitor, fork.id)
      assert length(copies) == 2

      dir_copy = Enum.find(copies, &(&1.path == "chapters"))
      child_copy = Enum.find(copies, &(&1.path == "chapters/one.typ"))

      # Fresh rows with the hierarchy remapped to the copied ids.
      assert dir_copy.id != dir.id
      assert child_copy.id != child.id
      assert child_copy.parent_id == dir_copy.id
      assert child_copy.content == "= One"

      # The source project is untouched and still the original owner's.
      originals = Files.get_file_tree(owner, project.id)
      assert Enum.map(originals, & &1.id) |> Enum.sort() == Enum.sort([dir.id, child.id])
    end

    test "an invalid name rolls the whole fork back", %{owner: owner, project: project} do
      file_fixture(project, owner, %{path: "main.typ", content: "= Hi"})
      visitor = user_scope_fixture()

      assert {:error, %Ecto.Changeset{}} = Projects.fork_project(visitor, project, %{name: ""})
      assert Projects.list_projects(visitor) == []
    end
  end
end
