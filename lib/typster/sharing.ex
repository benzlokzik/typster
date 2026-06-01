defmodule Typster.Sharing do
  @moduledoc """
  The Sharing context: public share links and project collaborators.

  Owner-management functions take a `%Scope{}` first and authorize against the
  project owner via `Projects.get_project!/2` (which raises for projects the
  scope's user does not own). Public token resolution does **not** take a scope.
  """

  import Ecto.Query, warn: false

  alias Typster.Accounts.Scope
  alias Typster.Projects
  alias Typster.Repo
  alias Typster.Sharing.Collaborator
  alias Typster.Sharing.Notifier
  alias Typster.Sharing.ShareLink

  ## Share links

  @doc """
  Returns the project's share link, creating one with a fresh token and the
  default `:read` scope if none exists yet. Authorizes via the project owner.
  """
  def get_or_create_link(%Scope{} = scope, project_id) do
    project = Projects.get_project!(scope, project_id)

    case Repo.get_by(ShareLink, project_id: project.id) do
      nil ->
        %ShareLink{project_id: project.id, token: ShareLink.gen_token(), scope: :read}
        |> Repo.insert!()

      %ShareLink{} = link ->
        link
    end
  end

  @doc """
  Updates an existing link's `:scope` and/or `:allow_download`. Authorizes the
  link's project against the scope owner before updating.
  """
  def update_link(%Scope{} = scope, %ShareLink{} = link, attrs) do
    _project = Projects.get_project!(scope, link.project_id)

    link
    |> ShareLink.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Rotates the link's token, invalidating the previous one. Authorizes via owner.
  """
  def rotate_link(%Scope{} = scope, %ShareLink{} = link) do
    _project = Projects.get_project!(scope, link.project_id)

    link
    |> Ecto.Changeset.change(token: ShareLink.gen_token())
    |> Repo.update()
  end

  @doc """
  PUBLIC: resolves a share link by its token, preloading the project.

  Returns `nil` for a blank or unknown token. Takes no scope by design.
  """
  def get_link_by_token(token) when is_binary(token) do
    case String.trim(token) do
      "" ->
        nil

      trimmed ->
        ShareLink
        |> where([l], l.token == ^trimmed)
        |> preload(:project)
        |> Repo.one()
    end
  end

  def get_link_by_token(_token), do: nil

  @doc """
  Returns a changeset for a share link, for use in forms.
  """
  def change_link(%ShareLink{} = link, attrs \\ %{}) do
    ShareLink.changeset(link, attrs)
  end

  @doc """
  PUBLIC: the source files of a share link's project, path-ordered.

  Takes no scope — the link itself is the authorization. Used to render the
  read-only shared/embedded view (and feed the client-side Typst compiler).
  """
  def files_for_link(%ShareLink{project_id: project_id}) do
    Typster.Projects.File
    |> where([f], f.project_id == ^project_id)
    |> order_by([f], asc: f.path)
    |> Repo.all()
  end

  ## Collaborators

  @doc """
  Lists a project's collaborators, oldest first. Authorizes via the owner.
  """
  def list_collaborators(%Scope{} = scope, project_id) do
    project = Projects.get_project!(scope, project_id)

    Collaborator
    |> where([c], c.project_id == ^project.id)
    |> order_by([c], asc: c.inserted_at)
    |> Repo.all()
  end

  @doc """
  Invites a collaborator by email with the given role (default `:viewer`).

  Inserts a `:pending` collaborator, then delivers an invite email. Delivery
  failures are swallowed so a transient mailer error never fails the invite.
  """
  def invite_collaborator(%Scope{} = scope, project_id, email, role \\ :viewer) do
    project = Projects.get_project!(scope, project_id)

    result =
      %Collaborator{project_id: project.id, status: :pending}
      |> Collaborator.changeset(%{email: email, role: role})
      |> Repo.insert()

    case result do
      {:ok, collaborator} ->
        deliver_invite_quietly(collaborator, project)
        {:ok, collaborator}

      {:error, _changeset} = error ->
        error
    end
  end

  @doc """
  Updates a collaborator's role. Authorizes via the collaborator's project.
  """
  def update_collaborator_role(%Scope{} = scope, %Collaborator{} = collaborator, role) do
    _project = Projects.get_project!(scope, collaborator.project_id)

    collaborator
    |> Collaborator.changeset(%{role: role})
    |> Repo.update()
  end

  @doc """
  Removes a collaborator. Authorizes via the collaborator's project.
  """
  def remove_collaborator(%Scope{} = scope, %Collaborator{} = collaborator) do
    _project = Projects.get_project!(scope, collaborator.project_id)
    Repo.delete(collaborator)
  end

  @doc """
  Returns a changeset for a collaborator, for use in forms.
  """
  def change_collaborator(%Collaborator{} = collaborator, attrs \\ %{}) do
    Collaborator.changeset(collaborator, attrs)
  end

  @doc """
  PUBLIC (bearer): accepts a pending invite for the authenticated user.

  The invite `id` is the bearer credential — the invitee is not the project
  owner, so authorization is the unguessable id itself, not project ownership.
  Links the collaborator row to the current user and marks it `:accepted`.

  Idempotent: re-accepting an already-accepted invite is a no-op success.
  Returns `{:ok, collaborator}` with the project preloaded, or
  `{:error, :not_found}` when the id is malformed or no invite exists.
  """
  def accept_invite(%Scope{user: %{id: user_id}}, invite_id) when is_binary(invite_id) do
    case fetch_collaborator(invite_id) do
      nil ->
        {:error, :not_found}

      %Collaborator{} = collaborator ->
        collaborator
        |> Collaborator.accept_changeset(user_id)
        |> Repo.update()
        |> case do
          {:ok, accepted} -> {:ok, Repo.preload(accepted, :project)}
          {:error, _changeset} = error -> error
        end
    end
  end

  def accept_invite(_scope, _invite_id), do: {:error, :not_found}

  defp fetch_collaborator(id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} -> Repo.get(Collaborator, uuid)
      :error -> nil
    end
  end

  ## Internal

  defp deliver_invite_quietly(%Collaborator{} = collaborator, project) do
    url = "#{TypsterWeb.Endpoint.url()}/invites/#{collaborator.id}"
    Notifier.deliver_collaborator_invite(collaborator.email, project.name, url)
  rescue
    _ -> :ok
  catch
    _, _ -> :ok
  end
end
