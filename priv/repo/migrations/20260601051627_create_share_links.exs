defmodule Typster.Repo.Migrations.CreateShareLinks do
  use Ecto.Migration

  def change do
    create table(:share_links, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :project_id, references(:projects, type: :binary_id, on_delete: :delete_all),
        null: false

      add :token, :string, null: false
      add :scope, :string, null: false, default: "read"
      add :allow_download, :boolean, null: false, default: true
      timestamps(type: :utc_datetime)
    end

    create unique_index(:share_links, [:token])
    create unique_index(:share_links, [:project_id])
  end
end
