defmodule Typster.Repo.Migrations.AddPlanToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :plan, :string, null: false, default: "free"
    end
  end
end
