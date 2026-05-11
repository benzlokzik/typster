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
  Shared floating nav used by both the marketing layout and the auth layout.
  Pass a `:nav_links` slot to render the section-link bar (marketing only).
  """
  attr :current_scope, :map, default: nil
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
        <button
          class="mk-btn mk-btn-ghost mk-btn-sm mk-theme-toggle"
          onclick="toggleMkTheme(this)"
          aria-label="Toggle theme"
        >
          <i data-lucide="moon" class="mk-icon-moon" aria-hidden="true"></i>
          <i data-lucide="sun" class="mk-icon-sun" aria-hidden="true"></i>
        </button>
        <%= if @current_scope && @current_scope.user do %>
          <a href={~p"/projects"} class="mk-btn mk-btn-ghost mk-btn-sm">My projects</a>
          <.link href={~p"/users/log-out"} method="delete" class="mk-btn mk-btn-ghost mk-btn-sm">
            Log out
          </.link>
        <% else %>
          <.link href={~p"/users/log-in"} class="mk-btn mk-btn-ghost mk-btn-sm">Log in</.link>
          <.link href={~p"/users/register"} class="mk-btn mk-btn-primary mk-btn-sm">
            Sign up free
          </.link>
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
    <header class="navbar px-4 sm:px-6 lg:px-8">
      <div class="flex-1">
        <a href={~p"/projects"} class="text-lg font-semibold">
          Typster
        </a>
      </div>
      <div class="flex-none">
        <ul class="flex flex-column px-1 space-x-4 items-center">
          <li>
            <.link navigate={~p"/projects"} class="btn btn-ghost">Projects</.link>
          </li>
          <li :if={@current_scope && @current_scope.user}>
            <.link navigate={~p"/users/settings"} class="btn btn-ghost">Settings</.link>
          </li>
          <li :if={@current_scope && @current_scope.user}>
            <.link href={~p"/users/log-out"} method="delete" class="btn btn-ghost">Log out</.link>
          </li>
          <li :if={!@current_scope || !@current_scope.user}>
            <.link navigate={~p"/users/log-in"} class="btn btn-ghost">Log in</.link>
          </li>
          <li>
            <.theme_toggle />
          </li>
        </ul>
      </div>
    </header>

    <main class="px-4 py-20 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-2xl space-y-4">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
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

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
