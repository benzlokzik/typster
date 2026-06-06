defmodule TypsterWeb.ErrorHTMLTest do
  use TypsterWeb.ConnCase, async: true

  # Bring render_to_string/4 for testing custom views
  import Phoenix.Template, only: [render_to_string: 4]

  test "renders a styled, self-contained 404.html" do
    html = render_to_string(TypsterWeb.ErrorHTML, "404", "html", [])

    # Standalone document that loads the app CSS itself (no app layout).
    assert html =~ "<!DOCTYPE html>"
    assert html =~ "/assets/css/app.css"
    # On-brand, voiced content + working escape hatches (English by default).
    assert html =~ "404"
    assert html =~ "Undefined reference"
    assert html =~ "ts-404"
    assert html =~ ~s(href="/")
    assert html =~ ~s(href="/projects")
  end

  test "a 404 falls back to English with no locale in the session", %{conn: conn} do
    body = conn |> get("/no-such-route-xyz") |> response(404)
    assert body =~ "Undefined reference."
    assert body =~ "page not found"
  end

  test "a 404 renders in the visitor's session locale (ru)", %{conn: conn} do
    body =
      conn
      |> Plug.Test.init_test_session(%{locale: "ru"})
      |> get("/no-such-route-xyz")
      |> response(404)

    assert body =~ "Висячая ссылка."
    assert body =~ "страница не найдена"
  end

  test "renders 500.html" do
    assert render_to_string(TypsterWeb.ErrorHTML, "500", "html", []) == "Internal Server Error"
  end
end
