defmodule Typster.Sharing do
  @moduledoc """
  The Sharing context: public share links and project collaborators.

  Owner-management functions take a `%Scope{}` first and authorize against the
  project owner via `Projects.get_project!/2` (which raises for projects the
  scope's user does not own). Public token resolution does **not** take a scope.
  """

  import Ecto.Query, warn: false

  alias Typster.Accounts.Scope
  alias Typster.Accounts.User
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
  PUBLIC: the link owner's `Scope`, for entitlement checks on the public/embed
  views (e.g. whether an embed may be an editable sandbox).

  This is strictly the **sharer's** plan, never the anonymous visitor's — the
  embed inherits the capabilities the owner pays for. Returns `nil` when the
  owner can't be resolved.
  """
  @spec owner_scope(ShareLink.t()) :: Scope.t() | nil
  def owner_scope(%ShareLink{} = link) do
    case Repo.preload(link, project: :user) do
      %{project: %{user: %User{} = user}} -> Scope.for_user(user)
      _ -> nil
    end
  end

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

  The invite `id` is the bearer credential, but it is **not** sufficient on its
  own: the invite is addressed to a specific email, so we only link it to a user
  whose account email matches that address (case-insensitive). Otherwise anyone
  authenticated — including the project owner clicking the link to "preview" it —
  would silently claim the invite and bind it to the wrong account, leaving the
  real invitee unable to see the project.

  Idempotent: re-accepting an already-accepted invite by the same user is a
  no-op success. Returns `{:ok, collaborator}` with the project preloaded,
  `{:error, :forbidden}` when the invite is for a different email, or
  `{:error, :not_found}` when the id is malformed or no invite exists.
  """
  def accept_invite(%Scope{user: %{id: user_id, email: email}}, invite_id)
      when is_binary(invite_id) do
    with %Collaborator{} = collaborator <- fetch_collaborator(invite_id),
         true <- same_email?(collaborator.email, email),
         {:ok, accepted} <-
           collaborator |> Collaborator.accept_changeset(user_id) |> Repo.update() do
      {:ok, Repo.preload(accepted, :project)}
    else
      nil -> {:error, :not_found}
      false -> {:error, :forbidden}
      {:error, _changeset} = error -> error
    end
  end

  def accept_invite(_scope, _invite_id), do: {:error, :not_found}

  @doc """
  Links every invite addressed to this user's email to their account and marks
  it `:accepted`, so projects shared with them appear in their list **without**
  having to click the email accept-link. The invite *email* is the source of
  truth for who an invite belongs to, so this also self-heals rows that were
  mis-linked to another account. Idempotent; returns the number of rows touched.
  """
  @spec link_invites_for_user(Scope.t()) :: non_neg_integer()
  def link_invites_for_user(%Scope{user: %User{id: user_id, email: email}})
      when is_binary(email) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {count, _} =
      from(c in Collaborator,
        where:
          fragment("lower(?)", c.email) == ^String.downcase(email) and
            (is_nil(c.user_id) or c.user_id != ^user_id or c.status != :accepted)
      )
      |> Repo.update_all(set: [user_id: user_id, status: :accepted, updated_at: now])

    count
  end

  def link_invites_for_user(_scope), do: 0

  defp same_email?(a, b) when is_binary(a) and is_binary(b),
    do: String.downcase(a) == String.downcase(b)

  defp same_email?(_a, _b), do: false

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
