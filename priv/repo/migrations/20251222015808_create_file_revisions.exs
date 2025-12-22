defmodule Typster.Repo.Migrations.CreateFileRevisions do
  use Ecto.Migration

  def change do
    create table(:file_revisions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :file_id, references(:files, type: :binary_id, on_delete: :delete_all), null: false
      add :content, :text, null: false
      add :sequence, :integer, null: false
      add :inserted_at, :utc_datetime, null: false
    end

    create index(:file_revisions, [:file_id])
    create index(:file_revisions, [:file_id, :sequence])
  end
end
