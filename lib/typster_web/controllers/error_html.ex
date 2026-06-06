defmodule TypsterWeb.ErrorHTML do
  @moduledoc """
  This module is invoked by your endpoint in case of errors on HTML requests.

  See config/config.exs.
  """
  use TypsterWeb, :html

  # Styled pages live in `error_html/` (currently `404.html.heex`). Error
  # responses don't go through the app layout, so each template is a standalone
  # document carrying its own `<head>` (CSS + theme bootstrap).
  embed_templates "error_html/*"

  # Everything without a dedicated template (500, etc.) falls back to the plain
  # status message. Kept adjacent so the `render/2` clauses stay grouped.
  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
