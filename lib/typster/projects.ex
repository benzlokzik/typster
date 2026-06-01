defmodule Typster.Projects do
  @moduledoc """
  The Projects context.
  """

  import Ecto.Query, warn: false
  alias Typster.Accounts.Scope
  alias Typster.Repo
  alias Typster.Projects.Project
  alias Typster.Sharing.Collaborator

  def list_projects(%Scope{user: user}) do
    from(p in Project,
      left_join: c in Collaborator,
      on: c.project_id == p.id and c.user_id == ^user.id and c.status == :accepted,
      where: p.user_id == ^user.id or not is_nil(c.id),
      distinct: true,
      order_by: [desc: p.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Returns a map of `%{project_id => file_count}` for every project the scope
  can reach — owned or shared as an accepted collaborator.
  """
  def file_counts(%Scope{user: user}) do
    from(f in Typster.Projects.File,
      join: p in Project,
      on: f.project_id == p.id,
      left_join: c in Collaborator,
      on: c.project_id == p.id and c.user_id == ^user.id and c.status == :accepted,
      where: p.user_id == ^user.id or not is_nil(c.id),
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

  @doc """
  Like `get_project!/2` but also grants access to accepted collaborators, not
  just the owner. Use this for **content** access (opening the editor, reading
  and writing files/assets). Project lifecycle (update/delete) and all sharing
  management stay owner-only via `get_project!/2`.
  """
  def get_editable_project!(%Scope{user: user}, id) do
    editable_query(user, id) |> Repo.one!()
  end

  @doc "Non-raising variant of `get_editable_project!/2`."
  def get_editable_project(%Scope{user: user}, id) do
    editable_query(user, id) |> Repo.one()
  end

  defp editable_query(user, id) do
    from(p in Project,
      left_join: c in Collaborator,
      on: c.project_id == p.id and c.user_id == ^user.id and c.status == :accepted,
      where: p.id == ^id and (p.user_id == ^user.id or not is_nil(c.id))
    )
  end

  @doc """
  Returns true when the scope's user owns the project, false for collaborators
  or strangers. Drives owner-only UI affordances (sharing management, delete).
  """
  def owner?(%Scope{user: %{id: user_id}}, %Project{user_id: user_id}), do: true
  def owner?(_scope, _project), do: false

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
