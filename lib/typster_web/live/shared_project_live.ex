defmodule TypsterWeb.SharedProjectLive do
  @moduledoc """
  Public, read-only view of a project shared via a link (`/p/:slug?key=…`) or
  embedded (`/embed/:token`). No authentication: the link token is the
  authorization. The document is compiled client-side in the visitor's browser
  (the same WASM worker the editor uses), so nothing is rendered server-side.

  Link `scope` decides what is shown:

    * `:read` / `:full` — the entry source (read-only) plus the live preview
    * `:output`         — the compiled preview only (source hidden)
  """
  use TypsterWeb, :live_view

  alias Typster.Embed
  alias Typster.Files
  alias Typster.Sharing

  @impl true
  def mount(params, _session, socket) do
    token = params["token"] || params["key"]

    case Sharing.get_link_by_token(token) do
      nil ->
        {:ok,
         assign(socket, link: nil, project: nil, page_title: gettext("share.public.invalid"))}

      link ->
        files = Sharing.files_for_link(link)
        entry = pick_entry(files, params["file"])
        embed? = socket.assigns.live_action == :embed
        # The owner's plan — not the visitor's — decides the embed capabilities.
        # Only resolve it for the embed (the `/p/:slug` page is always read-only).
        owner_scope = if embed?, do: Sharing.owner_scope(link), else: nil
        policy = Embed.policy(owner_scope, params)

        # Count this open once per page load — on the dead render, which happens
        # exactly once for both the embed (socket-less) and the `/p` view (whose
        # connected mount we skip). No-op unless the Pro analytics code is present.
        if not connected?(socket), do: Typster.Analytics.record(link.token)

        {:ok,
         socket
         |> assign(:link, link)
         |> assign(:project, link.project)
         |> assign(:scope_kind, link.scope)
         |> assign(:embed?, embed?)
         |> assign(:embed_theme, embed_theme(params["theme"]))
         |> assign(:show_preview?, params["preview"] != "0")
         |> assign(:editable?, policy.editable)
         |> assign(:unbranded?, policy.unbranded)
         |> assign(:cta_mode, policy.cta.mode)
         |> assign(:entry, entry)
         |> assign(:content, (entry && entry.content) || "")
         |> assign(:language, entry_language(entry))
         |> assign(:project_sources, project_sources(files))
         |> assign(:page_title, link.project.name)}
    end
  end

  # The embed honors `?theme=light|dark` (anything else inherits the host theme).
  defp embed_theme(theme) when theme in ~w(light dark), do: theme
  defp embed_theme(_), do: nil

  # `?file=path` selects which file the embed opens to; otherwise auto-pick.
  defp pick_entry(files, nil), do: entry_file(files)

  defp pick_entry(files, path) do
    Enum.find(files, &(&1.path == path)) || entry_file(files)
  end

  @impl true
  def render(%{link: nil} = assigns) do
    ~H"""
    <div class="mk-body share-public share-public--invalid" data-theme-scope>
      <div class="share-public__panel">
        <div class="t-glyph t-glyph--lg ts-serif">T</div>
        <h1>{gettext("share.public.invalid_title")}</h1>
        <p>{gettext("share.public.invalid_sub")}</p>
        <a href={~p"/"} class="ts-btn ts-btn--primary ts-btn--sm">{gettext("share.public.home")}</a>
      </div>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <div
      class={["mk-body", "share-public", @embed? && "share-public--embed"]}
      id={if(@embed?, do: "typster-embed")}
      data-theme={@embed_theme}
      data-theme-scope
    >
      <div class={[
        "embed-comp",
        (show_source?(@scope_kind) and @show_preview?) && "embed-comp--split"
      ]}>
        <div class="embed-bar">
          <span class="t-glyph ts-serif">T</span>
          <span class="slug truncate">{@project.name}</span>
          <span :if={@entry} class="file truncate">· {@entry.path}</span>
          <span class="spacer"></span>
          <span class={["ro-pill", scope_pill_tone(@scope_kind), @editable? && "ro-pill--edit"]}>
            <.icon
              name={if(@editable?, do: "hero-pencil-square", else: "hero-eye")}
              class="size-3"
            /> {if(@editable?, do: gettext("share.scope.sandbox"), else: scope_label(@scope_kind))}
          </span>
        </div>

        <section :if={show_source?(@scope_kind)} class="embed-source">
          <div
            id="editor-container"
            phx-hook="CodeMirror"
            phx-update="ignore"
            data-content={@content}
            data-file-id={@entry && @entry.id}
            data-file-name={@entry && @entry.path}
            data-readonly={to_string(!@editable?)}
            data-language={@language}
            data-project-sources={Jason.encode!(@project_sources)}
            data-project-assets="[]"
          >
          </div>
        </section>

        <section :if={@show_preview?} class="embed-preview">
          <div :if={!show_source?(@scope_kind)} class="embed-hidden-src" hidden>
            <div
              id="editor-container"
              phx-hook="CodeMirror"
              phx-update="ignore"
              data-content={@content}
              data-file-id=""
              data-file-name={@entry && @entry.path}
              data-readonly="true"
              data-language={@language}
              data-project-sources={Jason.encode!(@project_sources)}
              data-project-assets="[]"
            >
            </div>
          </div>
          <div
            id="preview-container"
            phx-hook="Preview"
            phx-update="ignore"
            class="ts-preview__scroll"
          >
            <div id="preview-placeholder" class="ts-preview__placeholder">
              <span class="ts-preview__placeholder-ic"><.icon name="hero-eye" class="size-8" /></span>
              <p>{gettext("editor.preview_placeholder")}</p>
            </div>
          </div>
        </section>

        <div :if={!@unbranded? or @cta_mode != :none} class="embed-foot">
          <span :if={!@unbranded?} class="powered">
            {gettext("share.public.powered_by")} <strong class="ts-serif">Typster</strong>
          </span>
          <span class="spacer"></span>
          <%= case @cta_mode do %>
            <% :none -> %>
            <% :signup -> %>
              <.link navigate={~p"/users/register"} class="embed-foot__cta">
                {gettext("share.embed.cta_signup")}
              </.link>
            <% :fork -> %>
              <.link navigate={~p"/projects/#{@project.id}/edit"} class="embed-foot__cta">
                {gettext("share.embed.cta_fork")}
              </.link>
            <% _ -> %>
              <.link navigate={~p"/projects/#{@project.id}/edit"} class="embed-foot__cta">
                {gettext("share.public.open_in_typster")}
              </.link>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # The public/embed view reuses the editor's client hooks (CodeMirror, Preview),
  # which push compile/outline/save events back to the LiveView. This view is
  # read-only and compiles entirely client-side, so there is no server state to
  # update — we accept and ignore them. Without this clause, the first
  # `update_preview` push would crash the LiveView (undefined handle_event/3).
  @impl true
  def handle_event(_event, _params, socket), do: {:noreply, socket}

  # ── helpers ──────────────────────────────────────────────────────────────
  defp show_source?(:output), do: false
  defp show_source?(_), do: true

  defp scope_label(:output), do: gettext("share.scope.output")
  defp scope_label(:full), do: gettext("share.scope.full")
  defp scope_label(_), do: gettext("share.scope.read")

  # The "compiled output only" scope gets its own success tone in the bar pill;
  # read/full share the neutral baseline. (Overridden by --edit on Pro sandboxes.)
  defp scope_pill_tone(:output), do: "ro-pill--output"
  defp scope_pill_tone(_), do: nil

  defp entry_file(files) do
    Enum.find(files, &(&1.path == "main.typ")) ||
      Enum.find(files, &(Files.editor_language(&1.path) == "typst")) ||
      List.first(files)
  end

  defp entry_language(nil), do: "typst"
  defp entry_language(%{path: path}), do: Files.editor_language(path)

  defp project_sources(files) do
    files
    |> Enum.filter(&Files.editable_file?/1)
    |> Enum.map(fn f ->
      %{path: f.path, content: f.content || "", language: Files.editor_language(f.path)}
    end)
  end
end
