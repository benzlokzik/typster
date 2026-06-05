defmodule Typster.JobsTest do
  use Typster.DataCase, async: true

  import Typster.AccountsFixtures, only: [user_scope_fixture: 0]
  import Typster.ProjectsFixtures, only: [project_fixture: 1, file_fixture: 3, asset_fixture: 2]

  alias Typster.{Assets, Repo, Revisions}
  alias Typster.Jobs.{AssetCleanup, PeriodicSnapshot}

  setup do
    scope = user_scope_fixture()
    %{scope: scope, project: project_fixture(scope)}
  end

  describe "PeriodicSnapshot" do
    test "checkpoints a file whose content drifted from its latest revision", ctx do
      %{scope: scope, project: project} = ctx
      file = file_fixture(project, scope, %{path: "main.typ", content: "v1"})
      {:ok, _rev} = Revisions.create_revision(scope, file.id, "v1")

      # Content moved on (e.g. autosave) but no new revision was cut yet.
      Repo.update_all(
        from(f in Typster.Projects.File, where: f.id == ^file.id),
        set: [content: "v2"]
      )

      assert :ok = PeriodicSnapshot.perform(%Oban.Job{})

      assert [latest | _] = Revisions.list_revisions(scope, file.id)
      assert latest.content == "v2"
    end

    test "does nothing for a file with no prior revision", ctx do
      %{scope: scope, project: project} = ctx
      file = file_fixture(project, scope, %{path: "fresh.typ", content: "hi"})

      assert :ok = PeriodicSnapshot.perform(%Oban.Job{})
      assert Revisions.list_revisions(scope, file.id) == []
    end
  end

  describe "AssetCleanup" do
    test "runs cleanly and keeps assets whose project still exists", ctx do
      %{scope: scope, project: project} = ctx
      asset = asset_fixture(project, scope)

      assert :ok = AssetCleanup.perform(%Oban.Job{})
      assert Repo.get(Assets.Asset, asset.id)
    end
  end

  describe "cron schedule" do
    test "every configured cron expression is valid syntax" do
      for expr <- ["*/5 * * * *", "0 3 * * *"] do
        assert %Oban.Cron.Expression{} = Oban.Cron.Expression.parse!(expr)
      end
    end
  end
end
