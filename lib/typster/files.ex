defmodule Typster.Files do
  @moduledoc """
  The Files context.
  """

  import Ecto.Query, warn: false
  alias Typster.Accounts.Scope
  alias Typster.Repo
  alias Typster.Projects.File

  @editable_extensions ~w(.typ .bib .md .yaml .yml .tex .latex .sty .cls)
  @asset_extensions ~w(.pdf .png .jpg .jpeg .svg .webp .ttf .otf .woff .woff2)

  def get_file!(%Scope{user: user}, id) do
    from(f in File,
      join: p in assoc(f, :project),
      where: f.id == ^id and p.user_id == ^user.id
    )
    |> Repo.one!()
  end

  def get_file(%Scope{user: user}, id) do
    from(f in File,
      join: p in assoc(f, :project),
      where: f.id == ^id and p.user_id == ^user.id
    )
    |> Repo.one()
  end

  def create_file(%Scope{} = scope, project_id, attrs \\ %{}) do
    _project = Typster.Projects.get_project!(scope, project_id)

    %File{project_id: project_id}
    |> File.changeset(attrs)
    |> Repo.insert()
  end

  def update_file_content(%Scope{} = scope, %File{} = file, content) do
    file = get_file!(scope, file.id)

    file
    |> File.changeset(%{content: content})
    |> Repo.update()
  end

  def update_file(%Scope{} = scope, %File{} = file, attrs) do
    file = get_file!(scope, file.id)

    file
    |> File.changeset(attrs)
    |> Repo.update()
  end

  def delete_file(%Scope{} = scope, %File{} = file) do
    file = get_file!(scope, file.id)
    Repo.delete(file)
  end

  def get_file_tree(%Scope{} = scope, project_id) do
    _project = Typster.Projects.get_project!(scope, project_id)

    from(f in File,
      where: f.project_id == ^project_id,
      preload: [:parent],
      order_by: [asc: f.path]
    )
    |> Repo.all()
  end

  def editable_file?(%File{path: path}), do: editable_path?(path)
  def editable_file?(path) when is_binary(path), do: editable_path?(path)
  def editable_file?(_), do: false

  def asset_file?(%File{path: path}), do: asset_path?(path)
  def asset_file?(path) when is_binary(path), do: asset_path?(path)
  def asset_file?(_), do: false

  def typst_file?(%File{path: path}), do: extension(path) == ".typ"
  def typst_file?(path) when is_binary(path), do: extension(path) == ".typ"
  def typst_file?(_), do: false

  def bibtex_file?(%File{path: path}), do: extension(path) == ".bib"
  def bibtex_file?(path) when is_binary(path), do: extension(path) == ".bib"
  def bibtex_file?(_), do: false

  def file_kind(%File{path: path}), do: file_kind(path)

  def file_kind(path) when is_binary(path) do
    cond do
      editable_path?(path) -> :text
      asset_path?(path) -> :asset
      true -> :unknown
    end
  end

  def file_kind(_), do: :unknown

  def editor_language(path) when is_binary(path) do
    case extension(path) do
      ".typ" -> "typst"
      ".bib" -> "bibtex"
      ".md" -> "markdown"
      ext when ext in ~w(.yaml .yml) -> "yaml"
      ext when ext in ~w(.tex .latex .sty .cls) -> "latex"
      _ -> "plain"
    end
  end

  def editor_language(_), do: "plain"

  defp editable_path?(path), do: extension(path) in @editable_extensions
  defp asset_path?(path), do: extension(path) in @asset_extensions
  defp extension(path), do: path |> Path.extname() |> String.downcase()

  def change_file(%File{} = file, attrs \\ %{}) do
    File.changeset(file, attrs)
  end
end
