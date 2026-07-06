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
    |> validate_path()
    |> validate_parent_in_project()
    |> assoc_constraint(:project)
    |> assoc_constraint(:parent)
    |> unique_constraint(:path,
      name: :files_project_id_path_index,
      message: "already exists in this project"
    )
  end

  # Paths are project-relative by contract (the preview VFS, S3 keys, and the
  # file tree all assume it): reject traversal segments, absolute paths,
  # backslashes, and empty segments instead of storing them verbatim.
  defp validate_path(changeset) do
    validate_change(changeset, :path, fn :path, path ->
      segments = String.split(path, "/")

      cond do
        String.starts_with?(path, "/") -> [path: "must be relative"]
        String.contains?(path, "\\") -> [path: "cannot contain backslashes"]
        Enum.any?(segments, &(&1 in ["..", "."])) -> [path: "cannot contain traversal segments"]
        Enum.any?(segments, &(String.trim(&1) == "")) -> [path: "cannot contain empty segments"]
        true -> []
      end
    end)
  end

  # A parent link must stay inside the same project — `cast` alone accepts any
  # existing file id (including another project's, or another tenant's), and
  # the FK cannot tell the difference.
  defp validate_parent_in_project(changeset) do
    parent_id = get_change(changeset, :parent_id)
    project_id = get_field(changeset, :project_id)

    if is_nil(parent_id) or is_nil(project_id) do
      changeset
    else
      import Ecto.Query, only: [from: 2]

      same_project? =
        Typster.Repo.exists?(
          from f in __MODULE__, where: f.id == ^parent_id and f.project_id == ^project_id
        )

      if same_project? do
        changeset
      else
        add_error(changeset, :parent_id, "does not belong to this project")
      end
    end
  end
end
