defmodule TypsterWeb.EmbedFramingTest do
  @moduledoc """
  Verifies the framing contract of the two public share surfaces:

    * `/embed/:token` runs through the `:embeddable` pipeline, which overrides
      the CSP to `frame-ancestors *` so third-party sites can iframe it.
    * `/p/:slug?key=…` runs through the default `:browser` pipeline, which pins
      `frame-ancestors 'self'` and so refuses cross-origin framing.

  The initial GET of a LiveView returns static HTML carrying the pipeline's
  response headers, so a plain `get/2` ConnCase request can inspect the CSP via
  `get_resp_header/2` without ever booting the LiveView socket.
  """
  use TypsterWeb.ConnCase, async: true

  alias Typster.Accounts.Scope
  alias Typster.Sharing

  import Typster.AccountsFixtures, only: [user_fixture: 0]
  import Typster.ProjectsFixtures, only: [project_fixture: 1, file_fixture: 3]

  setup %{conn: conn} do
    owner = user_fixture()
    scope = Scope.for_user(owner)
    project = project_fixture(owner)
    file_fixture(project, owner, %{path: "main.typ", content: "= Hi"})
    link = Sharing.get_or_create_link(scope, project.id)

    %{conn: conn, project: project, link: link}
  end

  # CSP header values can be split across multiple response-header entries, so
  # collapse them into a single lowercased string before substring matching.
  defp csp(conn) do
    conn
    |> get_resp_header("content-security-policy")
    |> Enum.join(" ")
    |> String.downcase()
  end

  describe "/embed/:token (the :embeddable pipeline)" do
    test "is framable from any origin and not pinned to 'self'", %{conn: conn, link: link} do
      conn = get(conn, ~p"/embed/#{link.token}")

      assert conn.status == 200

      csp = csp(conn)
      assert String.contains?(csp, "frame-ancestors *")
      refute String.contains?(csp, "frame-ancestors 'self'")
    end
  end

  describe "/p/:slug?key=token (the default :browser pipeline)" do
    test "pins frame-ancestors 'self' so it cannot be framed cross-origin", %{
      conn: conn,
      project: project,
      link: link
    } do
      conn = get(conn, ~p"/p/#{project.id}?#{[key: link.token]}")

      csp = csp(conn)
      assert String.contains?(csp, "frame-ancestors 'self'")
    end
  end
end
