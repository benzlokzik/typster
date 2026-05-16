defmodule TypsterWeb.LocaleController do
  use TypsterWeb, :controller

  @supported ~w(en ru)

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
