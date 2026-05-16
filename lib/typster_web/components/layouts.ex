defmodule TypsterWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use TypsterWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders the auth layout used by login and registration pages.
  Shares the same floating nav, background, and font system as the marketing page.
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def auth(assigns) do
    ~H"""
    <div class="mk-body auth-page">
      <.mk_nav current_scope={@current_scope} />
      <main class="auth-main">
        <div class="auth-card">
          {render_slot(@inner_block)}
        </div>
      </main>
      <.flash_group flash={@flash} />
    </div>
    """
  end

  @doc """
  Shared floating nav used by marketing, auth, and app layouts.
  Pass a `:nav_links` slot to render the section-link bar.
  Set `app_mode` to true on authenticated app pages to show only the logout CTA.
  """
  attr :current_scope, :map, default: nil
  attr :app_mode, :boolean, default: false
  slot :nav_links

  def mk_nav(assigns) do
    ~H"""
    <header class="mk-nav">
      <a href={~p"/"} class="mk-brand">
        <div class="mk-brand-mark">T</div>
        <span>Typster</span>
      </a>
      <nav :if={@nav_links != []} class="mk-nav-links">
        {render_slot(@nav_links)}
      </nav>
      <div class="mk-nav-cta">
        <.link
          href={
            ~p"/locale/#{if Gettext.get_locale(TypsterWeb.Gettext) == "ru", do: "en", else: "ru"}"
          }
          class="mk-btn mk-btn-ghost mk-btn-sm"
          aria-label="Switch language"
        >
          {if Gettext.get_locale(TypsterWeb.Gettext) == "ru", do: "EN", else: "RU"}
        </.link>
        <button
          class="mk-btn mk-btn-ghost mk-btn-sm mk-theme-toggle"
          onclick="toggleMkTheme(this)"
          aria-label={gettext("layout.theme.toggle")}
        >
          <i data-lucide="moon" class="mk-icon-moon" aria-hidden="true"></i>
          <i data-lucide="sun" class="mk-icon-sun" aria-hidden="true"></i>
        </button>
        <%= if @app_mode do %>
          <.link
            :if={@current_scope && @current_scope.user}
            href={~p"/users/log-out"}
            method="delete"
            class="mk-btn mk-btn-ghost mk-btn-sm"
          >
            {gettext("auth.log_out")}
          </.link>
        <% else %>
          <%= if @current_scope && @current_scope.user do %>
            <a href={~p"/projects"} class="mk-btn mk-btn-ghost mk-btn-sm">
              {gettext("nav.my_projects")}
            </a>
            <.link href={~p"/users/log-out"} method="delete" class="mk-btn mk-btn-ghost mk-btn-sm">
              {gettext("auth.log_out")}
            </.link>
          <% else %>
            <.link href={~p"/users/log-in"} class="mk-btn mk-btn-ghost mk-btn-sm">
              {gettext("auth.log_in")}
            </.link>
            <.link href={~p"/users/register"} class="mk-btn mk-btn-primary mk-btn-sm">
              {gettext("auth.sign_up")}
            </.link>
          <% end %>
        <% end %>
      </div>
    </header>
    """
  end

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="ts-app">
      <.mk_nav app_mode={true} current_scope={@current_scope}>
        <:nav_links>
          <.link navigate={~p"/projects"}>{gettext("nav.projects")}</.link>
          <.link :if={@current_scope && @current_scope.user} navigate={~p"/users/settings"}>
            {gettext("nav.settings")}
          </.link>
        </:nav_links>
      </.mk_nav>
      <div
        id="connection-banner"
        class="ts-conn-banner"
        phx-disconnected={JS.remove_attribute("hidden")}
        phx-connected={JS.set_attribute({"hidden", ""})}
        hidden
      >
        <.icon name="hero-arrow-path" class="size-3 motion-safe:animate-spin" />
        <span>{gettext("app.connection_lost")}</span>
      </div>
      {render_slot(@inner_block)}
      <.flash_group flash={@flash} />
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "mk-toast-stack", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} class="mk-toast-stack" aria-live="polite" aria-atomic="false">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="ts-toggle">
      <button
        class="ts-toggle__btn"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
        aria-label={gettext("layout.theme.system")}
      >
        <.icon name="hero-computer-desktop-micro" class="size-3.5" />
      </button>
      <button
        class="ts-toggle__btn"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
        aria-label={gettext("layout.theme.light")}
      >
        <.icon name="hero-sun-micro" class="size-3.5" />
      </button>
      <button
        class="ts-toggle__btn"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
        aria-label={gettext("layout.theme.dark")}
      >
        <.icon name="hero-moon-micro" class="size-3.5" />
      </button>
    </div>
    """
  end
end
