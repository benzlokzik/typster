defmodule Typster.Repo.Migrations.CreateTemplates do
  use Ecto.Migration

  def change do
    create table(:templates, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :name, :text, null: false
      add :content, :text
      timestamps(type: :utc_datetime)
    end

    create index(:templates, [:user_id])
  end
end
