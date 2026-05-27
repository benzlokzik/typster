defmodule Typster.Projects.File do
  @moduledoc "Schema for project files, including parent-child file relationships"
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "files" do
    field :path, :string
    field :content, :string
    field :pinned, :boolean, default: false
    belongs_to :project, Typster.Projects.Project
    belongs_to :parent, Typster.Projects.File
    has_many :children, Typster.Projects.File, foreign_key: :parent_id
    has_many :revisions, Typster.Projects.FileRevision
    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(file, attrs) do
    file
    |> cast(attrs, [:path, :content, :parent_id])
    |> validate_required([:path, :project_id])
    |> assoc_constraint(:project)
    |> unique_constraint(:path,
      name: :files_project_id_path_index,
      message: "already exists in this project"
    )
  end
end
