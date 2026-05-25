defmodule TypsterWeb.LocaleController do
  use TypsterWeb, :controller

  @supported ~w(en ru)

  @doc "Locales the app accepts. Single source of truth for locale validation."
  def supported, do: @supported

  def set(conn, %{"locale" => locale}) when locale in @supported do
    referer = get_req_header(conn, "referer") |> List.first("/")
    path = URI.parse(referer).path || "/"

    conn
    |> put_session(:locale, locale)
    |> redirect(to: path)
  end

  def set(conn, _params) do
    redirect(conn, to: "/")
  end
end
