defmodule Typster.Repo.Migrations.CreateFiles do
  use Ecto.Migration

  def change do
    create table(:files, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :project_id, references(:projects, type: :binary_id, on_delete: :delete_all),
        null: false

      add :path, :text, null: false
      add :content, :text
      add :parent_id, references(:files, type: :binary_id, on_delete: :delete_all)
      timestamps(type: :utc_datetime)
    end

    create index(:files, [:project_id])
    create index(:files, [:parent_id])
  end
end
