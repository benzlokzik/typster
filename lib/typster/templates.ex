defmodule Typster.Templates do
  @moduledoc """
  The Templates context: a user's own reusable starting points for new files.
  """

  import Ecto.Query, warn: false
  alias Typster.Accounts.Scope
  alias Typster.Repo
  alias Typster.Templates.Template

  @doc "List the current user's templates, newest first."
  def list_templates(%Scope{user: user}) do
    from(t in Template, where: t.user_id == ^user.id, order_by: [desc: t.updated_at])
    |> Repo.all()
  end

  def get_template!(%Scope{user: user}, id) do
    from(t in Template, where: t.id == ^id and t.user_id == ^user.id)
    |> Repo.one!()
  end

  @doc "Save a new template owned by the current user."
  def create_template(%Scope{user: user}, attrs) do
    %Template{user_id: user.id}
    |> Template.changeset(attrs)
    |> Repo.insert()
  end

  def delete_template(%Scope{} = scope, %Template{} = template) do
    template = get_template!(scope, template.id)
    Repo.delete(template)
  end
end
