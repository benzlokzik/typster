defmodule Typster.Repo.Migrations.UniqueFilePathPerProject do
  use Ecto.Migration

  def change do
    create unique_index(:files, [:project_id, :path])
  end
end
