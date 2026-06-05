defmodule TypsterWeb.UserSocket do
  @moduledoc """
  Socket for non-LiveView channels (currently the Yjs collaboration channel).

  Authenticated from the same session cookie as the rest of the app — the
  editor page is same-origin, so the cookie reaches the socket. Anonymous
  connections are allowed to open the socket but carry no user, so the
  `DocumentChannel` denies them per-file.
  """
  use Phoenix.Socket

  alias Typster.Accounts

  channel "doc:*", TypsterWeb.DocumentChannel

  @impl true
  def connect(_params, socket, connect_info) do
    user =
      with %{} = session <- connect_info[:session],
           token when is_binary(token) <- session["user_token"],
           %Accounts.User{} = user <- Accounts.get_user_by_session_token(token) |> user_of() do
        user
      else
        _ -> nil
      end

    {:ok, assign(socket, user: user)}
  end

  # get_user_by_session_token/1 returns {user, token_inserted_at} or nil.
  defp user_of({%Accounts.User{} = user, _inserted_at}), do: user
  defp user_of(%Accounts.User{} = user), do: user
  defp user_of(_), do: nil

  @impl true
  def id(%{assigns: %{user: %Accounts.User{id: id}}}), do: "user_socket:#{id}"
  def id(_socket), do: nil
end
