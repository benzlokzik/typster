defmodule Typster.Repo.Migrations.CreateCollaborators do
  use Ecto.Migration

  def change do
    create table(:collaborators, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :project_id, references(:projects, type: :binary_id, on_delete: :delete_all),
        null: false

      add :email, :string, null: false
      add :role, :string, null: false, default: "viewer"
      add :status, :string, null: false, default: "pending"
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      timestamps(type: :utc_datetime)
    end

    create index(:collaborators, [:project_id])
    create index(:collaborators, [:user_id])
    create unique_index(:collaborators, [:project_id, :email])
  end
end
