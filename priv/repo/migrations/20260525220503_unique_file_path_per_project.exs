defmodule Typster.Repo.Migrations.UniqueFilePathPerProject do
  use Ecto.Migration

  def up do
    # Pre-existing data may already contain duplicate (project_id, path) rows
    # from before this constraint. Collapse each group to the most recently
    # updated row (ties broken by id) so the unique index can be created.
    execute("""
    DELETE FROM files a
    USING files b
    WHERE a.project_id = b.project_id
      AND a.path = b.path
      AND a.id <> b.id
      AND (a.updated_at < b.updated_at
           OR (a.updated_at = b.updated_at AND a.id < b.id))
    """)

    create unique_index(:files, [:project_id, :path])
  end

  def down do
    drop unique_index(:files, [:project_id, :path])
  end
end
