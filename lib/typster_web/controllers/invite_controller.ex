defmodule TypsterWeb.InviteController do
  @moduledoc """
  Accepts a collaboration invite delivered by email at `/invites/:id`.

  The route lives behind `:require_authenticated_user`, so an unregistered
  invitee is bounced to log-in/registration first (the plug stashes this path
  as `:user_return_to`) and lands back here authenticated, where the invite is
  linked to their freshly created account.
  """
  use TypsterWeb, :controller

  alias Typster.Sharing

  def show(conn, %{"id" => id}) do
    case Sharing.accept_invite(conn.assigns.current_scope, id) do
      {:ok, collaborator} ->
        conn
        |> put_flash(:info, gettext("share.invite.accepted"))
        |> redirect(to: ~p"/projects/#{collaborator.project_id}/edit")

      {:error, :forbidden} ->
        conn
        |> put_flash(:error, gettext("share.invite.wrong_account"))
        |> redirect(to: ~p"/projects")

      {:error, :not_found} ->
        conn
        |> put_flash(:error, gettext("share.invite.invalid"))
        |> redirect(to: ~p"/projects")
    end
  end
end
