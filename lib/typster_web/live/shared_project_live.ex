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
        entry = entry_file(files)

        {:ok,
         socket
         |> assign(:link, link)
         |> assign(:project, link.project)
         |> assign(:scope_kind, link.scope)
         |> assign(:embed?, socket.assigns.live_action == :embed)
         |> assign(:entry, entry)
         |> assign(:content, (entry && entry.content) || "")
         |> assign(:language, entry_language(entry))
         |> assign(:project_sources, project_sources(files))
         |> assign(:page_title, link.project.name)}
    end
  end

  @impl true
  def render(%{link: nil} = assigns) do
    ~H"""
    <div class="mk-body share-public share-public--invalid">
      <div class="share-public__panel">
        <div class="ts-emptystate__tile ts-serif">T</div>
        <h1>{gettext("share.public.invalid_title")}</h1>
        <p>{gettext("share.public.invalid_sub")}</p>
        <a href={~p"/"} class="ts-btn ts-btn--primary ts-btn--sm">{gettext("share.public.home")}</a>
      </div>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <div class={["mk-body", "share-public", @embed? && "share-public--embed"]} data-theme-scope>
      <header class="share-public__bar">
        <span class="ts-tb__proj-glyph ts-serif">T</span>
        <span class="share-public__name truncate">{@project.name}</span>
        <span :if={@entry} class="share-public__file">· {@entry.path}</span>
        <span class="share-public__pill">{scope_label(@scope_kind)}</span>
        <div class="ts-spacer" />
        <.link navigate={~p"/projects/#{@project.id}/edit"} class="ts-btn ts-btn--primary ts-btn--sm">
          {gettext("share.public.open_in_typster")}
        </.link>
      </header>

      <div class={["share-public__body", show_source?(@scope_kind) && "with-source"]}>
        <section :if={show_source?(@scope_kind)} class="share-public__source">
          <div
            id="editor-container"
            phx-hook="CodeMirror"
            phx-update="ignore"
            data-content={@content}
            data-file-id=""
            data-readonly="true"
            data-language={@language}
            data-project-sources={Jason.encode!(@project_sources)}
            data-project-assets="[]"
            class="ts-source__editor"
          >
          </div>
        </section>

        <section class="share-public__preview">
          <div :if={!show_source?(@scope_kind)} class="share-public__hidden-src" hidden>
            <div
              id="editor-container"
              phx-hook="CodeMirror"
              phx-update="ignore"
              data-content={@content}
              data-file-id=""
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
              <span style="color: var(--mk-fg4);"><.icon name="hero-eye" class="size-8" /></span>
              <p>{gettext("editor.preview_placeholder")}</p>
            </div>
          </div>
        </section>
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
