defmodule TypsterWeb.UserSessionController do
  use TypsterWeb, :controller

  alias Typster.Accounts
  alias TypsterWeb.UserAuth

  def create(conn, %{"_action" => "confirmed"} = params) do
    create(conn, params, gettext("auth.flash.confirmed"))
  end

  def create(conn, params) do
    create(conn, params, gettext("auth.flash.welcome_back"))
  end

  # magic link login
  defp create(conn, %{"user" => %{"token" => token} = user_params}, info) do
    case Accounts.login_user_by_magic_link(token) do
      {:ok, {user, tokens_to_disconnect}} ->
        UserAuth.disconnect_sessions(tokens_to_disconnect)

        conn
        |> put_flash(:info, info)
        |> UserAuth.log_in_user(user, user_params)

      _ ->
        conn
        |> put_flash(:error, gettext("auth.flash.link_invalid"))
        |> redirect(to: ~p"/users/log-in")
    end
  end

  # magic link request — no-JS fallback when the email-only form is submitted
  defp create(conn, %{"user" => %{"email" => email} = user_params}, _info)
       when not is_map_key(user_params, "password") do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_login_instructions(
        user,
        &url(~p"/users/log-in/#{&1}")
      )
    end

    conn
    |> put_flash(
      :info,
      gettext("auth.flash.magic_link_sent")
    )
    |> redirect(to: ~p"/users/log-in")
  end

  # email + password login
  defp create(conn, %{"user" => user_params}, info) do
    %{"email" => email, "password" => password} = user_params

    if user = Accounts.get_user_by_email_and_password(email, password) do
      conn
      |> put_flash(:info, info)
      |> UserAuth.log_in_user(user, user_params)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      conn
      |> put_flash(:error, gettext("auth.flash.invalid_credentials"))
      |> put_flash(:email, String.slice(email, 0, 160))
      |> redirect(to: ~p"/users/log-in")
    end
  end

  def update_password(conn, %{"user" => user_params} = params) do
    user = conn.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)
    {:ok, {_user, expired_tokens}} = Accounts.update_user_password(user, user_params)

    # disconnect all existing LiveViews with old sessions
    UserAuth.disconnect_sessions(expired_tokens)

    conn
    |> put_session(:user_return_to, ~p"/users/settings")
    |> create(params, gettext("auth.flash.password_updated"))
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, gettext("auth.flash.logged_out"))
    |> UserAuth.log_out_user()
  end
end
