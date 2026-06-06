defmodule TypsterWeb.ErrorHTMLTest do
  use TypsterWeb.ConnCase, async: true

  # Bring render_to_string/4 for testing custom views
  import Phoenix.Template, only: [render_to_string: 4]

  test "renders a styled, self-contained 404.html" do
    html = render_to_string(TypsterWeb.ErrorHTML, "404", "html", [])

    # Standalone document that loads the app CSS itself (no app layout).
    assert html =~ "<!DOCTYPE html>"
    assert html =~ "/assets/css/app.css"
    # On-brand, voiced content + working escape hatches.
    assert html =~ "404"
    assert html =~ "Undefined reference"
    assert html =~ "ts-404"
    assert html =~ ~s(href="/")
    assert html =~ ~s(href="/projects")
  end

  test "renders 500.html" do
    assert render_to_string(TypsterWeb.ErrorHTML, "500", "html", []) == "Internal Server Error"
  end
end
