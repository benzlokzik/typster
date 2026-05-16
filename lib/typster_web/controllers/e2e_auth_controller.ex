defmodule TypsterWeb.E2EAuthController do
  use TypsterWeb, :controller

  alias Typster.Accounts
  alias Typster.Accounts.Scope
  alias Typster.Accounts.User
  alias Typster.Repo
  alias TypsterWeb.UserAuth

  def create(conn, params) do
    email =
      params
      |> Map.get("email", default_email())
      |> String.trim()
      |> String.downcase()

    user =
      case Accounts.get_user_by_email(email) do
        nil -> insert_confirmed_user!(email)
        existing -> ensure_confirmed!(existing)
      end

    # Update current_scope so signed_in_path/1 resolves to /projects.
    # Clear user_return_to so log_in_user does not redirect to a stale URL
    # captured from a previous unauthenticated request.
    conn
    |> Plug.Conn.assign(:current_scope, Scope.for_user(user))
    |> Plug.Conn.delete_session(:user_return_to)
    |> UserAuth.log_in_user(user)
  end

  defp insert_confirmed_user!(email) do
    now = DateTime.utc_now(:second)

    %User{}
    |> Ecto.Changeset.change(%{
      email: email,
      hashed_password: Bcrypt.hash_pwd_salt("e2e-unused"),
      confirmed_at: now
    })
    |> Repo.insert!()
  end

  defp ensure_confirmed!(%User{confirmed_at: nil} = user) do
    user
    |> Ecto.Changeset.change(confirmed_at: DateTime.utc_now(:second))
    |> Repo.update!()
  end

  defp ensure_confirmed!(user), do: user

  defp default_email do
    unique = System.unique_integer([:positive, :monotonic])
    "e2e-#{unique}@typster.test"
  end
end
