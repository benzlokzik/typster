defmodule Typster.Repo.Migrations.AddPinnedToFiles do
  use Ecto.Migration

  def change do
    alter table(:files) do
      add :pinned, :boolean, null: false, default: false
    end
  end
end
