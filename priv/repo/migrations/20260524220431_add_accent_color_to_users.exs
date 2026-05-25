defmodule Typster.Repo.Migrations.AddAccentColorToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :accent_color, :string, null: false, default: "indigo"
    end
  end
end
