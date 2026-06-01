defmodule Typster.CollabTest do
  use Typster.DataCase, async: true

  import Typster.AccountsFixtures, only: [user_scope_fixture: 0]
  import Typster.ProjectsFixtures, only: [project_fixture: 1, file_fixture: 3]

  alias Typster.Collab
  alias Typster.Collab.FilePersistence

  # `Collab.get_or_start_doc/1` starts a `Yex.Sync.SharedDoc` whose `init` calls
  # `FilePersistence.bind/3` synchronously — that `Repo.get` deadlocks the single
  # shared sandbox connection in tests (a harness limitation; a real pool is fine,
  # and the channel join is covered by the browser/integration test). So here we
  # exercise the seeding logic directly and the registry lookup.

  setup do
    scope = user_scope_fixture()
    project = project_fixture(scope)
    %{scope: scope, project: project}
  end

  describe "FilePersistence.bind/3 (document seeding)" do
    test "seeds the shared Y.Text from the file's saved content", %{
      scope: scope,
      project: project
    } do
      file = file_fixture(project, scope, %{path: "main.typ", content: "= Hello collab"})

      doc = Yex.Doc.new()
      assert FilePersistence.bind(file.id, file.id, doc) == file.id

      text = doc |> Yex.Doc.get_text("content") |> Yex.Text.to_string()
      assert text == "= Hello collab"
    end

    test "leaves the doc empty for an empty file", %{scope: scope, project: project} do
      file = file_fixture(project, scope, %{path: "blank.typ", content: ""})

      doc = Yex.Doc.new()
      FilePersistence.bind(file.id, file.id, doc)

      assert doc |> Yex.Doc.get_text("content") |> Yex.Text.to_string() == ""
    end

    test "leaves the doc empty for a missing file" do
      doc = Yex.Doc.new()
      FilePersistence.bind(Ecto.UUID.generate(), "missing", doc)

      assert doc |> Yex.Doc.get_text("content") |> Yex.Text.to_string() == ""
    end
  end

  describe "registry" do
    test "whereis returns nil for a file with no open room" do
      assert Collab.whereis(Ecto.UUID.generate()) == nil
    end
  end
end
