defmodule Typster.Jobs.AssetCleanup do
  @moduledoc "Oban job that deletes assets whose parent project no longer exists"
  use Oban.Worker, queue: :default, max_attempts: 3

  @impl Oban.Worker
  def perform(_job) do
    alias Typster.Repo

    import Ecto.Query

    all_assets = Repo.all(Typster.Assets.Asset)

    # `select: p.id` already returns a flat list of ids — use it directly (a
    # MapSet keeps the membership check O(1) across many assets).
    project_ids =
      from(p in Typster.Projects.Project, select: p.id)
      |> Repo.all()
      |> MapSet.new()

    orphaned_assets =
      Enum.filter(all_assets, fn asset ->
        not MapSet.member?(project_ids, asset.project_id)
      end)

    Enum.each(orphaned_assets, fn asset ->
      Repo.delete(asset)
    end)

    :ok
  end
end
