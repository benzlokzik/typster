defmodule Typster.Projects do
  @moduledoc """
  The Projects context.
  """

  import Ecto.Query, warn: false
  alias Typster.Accounts.Scope
  alias Typster.Repo
  alias Typster.Projects.Project

  def list_projects(%Scope{user: user}) do
    from(p in Project, where: p.user_id == ^user.id, order_by: [desc: p.inserted_at])
    |> Repo.all()
  end

  @doc """
  Returns a map of `%{project_id => file_count}` for the scope's projects.
  """
  def file_counts(%Scope{user: user}) do
    from(f in Typster.Projects.File,
      join: p in Project,
      on: f.project_id == p.id,
      where: p.user_id == ^user.id,
      group_by: f.project_id,
      select: {f.project_id, count(f.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  def get_project!(%Scope{user: user}, id) do
    from(p in Project, where: p.id == ^id and p.user_id == ^user.id)
    |> Repo.one!()
  end

  def get_project(%Scope{user: user}, id) do
    from(p in Project, where: p.id == ^id and p.user_id == ^user.id)
    |> Repo.one()
  end

  def create_project(%Scope{user: user}, attrs \\ %{}) do
    %Project{user_id: user.id}
    |> Project.changeset(attrs)
    |> Repo.insert()
  end

  def update_project(%Scope{} = scope, %Project{} = project, attrs) do
    project = get_project!(scope, project.id)

    project
    |> Project.changeset(attrs)
    |> Repo.update()
  end

  def delete_project(%Scope{} = scope, %Project{} = project) do
    project = get_project!(scope, project.id)
    Repo.delete(project)
  end

  def change_project(%Project{} = project, attrs \\ %{}) do
    Project.changeset(project, attrs)
  end
end
