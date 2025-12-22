defmodule Typster.Repo.Migrations.CreateAssets do
  use Ecto.Migration

  def change do
    create table(:assets, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :project_id, references(:projects, type: :binary_id, on_delete: :delete_all),
        null: false

      add :object_key, :text, null: false
      add :content_type, :string, null: false
      add :size, :integer, null: false
      add :filename, :string, null: false
      add :inserted_at, :utc_datetime, null: false
    end

    create index(:assets, [:project_id])
    create unique_index(:assets, [:project_id, :object_key])
  end
end
