defmodule Typster.Repo.Migrations.AddJoinPoliciesToShareLinks do
  use Ecto.Migration

  def change do
    alter table(:share_links) do
      # Both default to false: visitors can neither copy the project nor join
      # as collaborators until the owner explicitly opts in per link.
      add :allow_fork, :boolean, default: false, null: false
      add :open_edit, :boolean, default: false, null: false
    end
  end
end
