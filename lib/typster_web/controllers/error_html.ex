defmodule TypsterWeb.ErrorHTML do
  @moduledoc """
  This module is invoked by your endpoint in case of errors on HTML requests.

  See config/config.exs.
  """
  use TypsterWeb, :html

  # Styled pages live in `error_html/` (currently `not_found.html.heex`). Error
  # responses don't go through the app layout, so each template is a standalone
  # document carrying its own `<head>` (CSS + theme bootstrap).
  embed_templates "error_html/*"

  # A 404 is raised before the router runs, so the `:set_locale` pipeline plug
  # never fired — pull the locale straight from the session here, then delegate
  # to the gettext'd template so it renders in the visitor's language.
  def render("404.html", assigns) do
    Gettext.put_locale(TypsterWeb.Gettext, locale(assigns))
    # `embed_templates` names the component after the file stem (`not_found/1`).
    not_found(assigns)
  end

  # Everything without a dedicated template (500, etc.) falls back to the plain
  # status message. Kept adjacent so the `render/2` clauses stay grouped.
  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end

  @locales ~w(en ru)

  defp locale(%{conn: %Plug.Conn{} = conn}) do
    case conn |> Plug.Conn.fetch_session() |> Plug.Conn.get_session(:locale) do
      loc when loc in @locales -> loc
      _ -> "en"
    end
  rescue
    # No session configured (e.g. a non-browser request) — fall back to English.
    _ -> "en"
  end

  defp locale(_assigns), do: "en"
end
