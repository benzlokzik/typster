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
        # The owner's plan — not the visitor's — decides the embed capabilities
        # and whether `open_edit` may hand out collaborator seats. Resolve it
        # only when a policy actually needs it.
        owner_scope =
          if embed? or link.open_edit, do: Sharing.owner_scope(link), else: nil

        policy = Embed.policy(owner_scope, params)

        # Join/fork actions live on the `/p/:slug` page only: the embed renders
        # statically inside third-party iframes (no LiveView socket to push
        # events over), so it keeps its plain-anchor CTA instead.
        can_join? =
          not embed? and Typster.Sharing.Collaboration.open_edit?(owner_scope, link)

        can_fork? = not embed? and link.allow_fork

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
         |> assign(:can_join?, can_join?)
         |> assign(:can_fork?, can_fork?)
         |> assign(:fork_open?, false)
         |> assign(:notice, nil)
         |> assign(:fork_form, to_form(%{"name" => copy_name(link.project.name)}, as: :fork))
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
          <%= if @can_fork? do %>
            <%= if @current_scope && @current_scope.user do %>
              <button
                type="button"
                id="shared-fork-open"
                class="ts-btn ts-btn--ghost ts-btn--sm"
                phx-click="open_fork"
              >
                <.icon name="hero-document-duplicate" class="size-3.5" /> {gettext("share.join.fork")}
              </button>
            <% else %>
              <.link
                navigate={~p"/users/log-in"}
                id="shared-fork-login"
                class="ts-btn ts-btn--ghost ts-btn--sm"
              >
                <.icon name="hero-document-duplicate" class="size-3.5" /> {gettext("share.join.fork")}
              </.link>
            <% end %>
          <% end %>
          <%= if @can_join? do %>
            <%= if @current_scope && @current_scope.user do %>
              <button
                type="button"
                id="shared-join"
                class="ts-btn ts-btn--primary ts-btn--sm"
                phx-click="join"
              >
                <.icon name="hero-pencil-square" class="size-3.5" /> {gettext("share.join.edit")}
              </button>
            <% else %>
              <.link
                navigate={~p"/users/log-in"}
                id="shared-join-login"
                class="ts-btn ts-btn--primary ts-btn--sm"
              >
                <.icon name="hero-pencil-square" class="size-3.5" /> {gettext("share.join.edit")}
              </.link>
            <% end %>
          <% end %>
          <span class={["ro-pill", scope_pill_tone(@scope_kind), @editable? && "ro-pill--edit"]}>
            <.icon
              name={if(@editable?, do: "hero-pencil-square", else: "hero-eye")}
              class="size-3"
            /> {if(@editable?, do: gettext("share.scope.sandbox"), else: scope_label(@scope_kind))}
          </span>
        </div>

        <div :if={@notice} id="shared-notice" class="embed-bar" role="alert">
          <.icon name="hero-exclamation-triangle" class="size-3.5" />
          <span class="truncate">{@notice}</span>
        </div>

        <div
          :if={@fork_open?}
          class="share-public__fork-overlay"
          phx-window-keydown="close_fork"
          phx-key="escape"
        >
          <div class="share-public__panel">
            <h2>{gettext("share.join.fork_title")}</h2>
            <p>{gettext("share.join.fork_sub")}</p>
            <.form for={@fork_form} id="shared-fork-form" phx-submit="fork">
              <.input
                field={@fork_form[:name]}
                type="text"
                label={gettext("share.join.fork_name")}
                autofocus
              />
              <div style="display:flex; gap:8px; margin-top:12px; justify-content:flex-end;">
                <button type="button" class="ts-btn ts-btn--ghost ts-btn--sm" phx-click="close_fork">
                  {gettext("share.join.fork_cancel")}
                </button>
                <button type="submit" class="ts-btn ts-btn--primary ts-btn--sm">
                  {gettext("share.join.fork_confirm")}
                </button>
              </div>
            </.form>
          </div>
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
          <%!-- Plain anchors, not `navigate`: the embed renders without a
                LiveView socket, and inside a third-party iframe our session
                cookie is blocked anyway — these must escape to a new
                top-level window on our origin. --%>
          <%= case @cta_mode do %>
            <% :none -> %>
            <% :signup -> %>
              <a
                href={~p"/users/register"}
                target={@embed? && "_blank"}
                rel={@embed? && "noopener"}
                class="embed-foot__cta"
              >
                {gettext("share.embed.cta_signup")}
              </a>
            <% :fork -> %>
              <a
                href={~p"/projects/#{@project.id}/edit"}
                target={@embed? && "_blank"}
                rel={@embed? && "noopener"}
                class="embed-foot__cta"
              >
                {gettext("share.embed.cta_fork")}
              </a>
            <% _ -> %>
              <a
                href={~p"/projects/#{@project.id}/edit"}
                target={@embed? && "_blank"}
                rel={@embed? && "noopener"}
                class="embed-foot__cta"
              >
                {gettext("share.public.open_in_typster")}
              </a>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("open_fork", _params, %{assigns: %{can_fork?: true}} = socket) do
    {:noreply, assign(socket, :fork_open?, true)}
  end

  def handle_event("close_fork", _params, socket) do
    {:noreply, assign(socket, :fork_open?, false)}
  end

  def handle_event(
        "fork",
        %{"fork" => %{"name" => name}},
        %{assigns: %{can_fork?: true}} = socket
      ) do
    scope = socket.assigns.current_scope

    case Sharing.fork_via_link(scope, socket.assigns.link.token, %{name: name}) do
      {:ok, project} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("share.join.forked", name: project.name))
         |> push_navigate(to: ~p"/projects/#{project.id}/edit")}

      {:error, %Ecto.Changeset{}} ->
        {:noreply,
         socket
         |> assign(:fork_form, to_form(%{"name" => name}, as: :fork))
         |> assign(:notice, gettext("share.join.fork_invalid_name"))}

      {:error, _reason} ->
        {:noreply,
         socket
         |> assign(:fork_open?, false)
         |> assign(:notice, gettext("share.join.fork_failed"))}
    end
  end

  def handle_event("join", _params, %{assigns: %{can_join?: true}} = socket) do
    scope = socket.assigns.current_scope

    case Sharing.join_via_link(scope, socket.assigns.link.token) do
      {:ok, _collaborator_or_owner} ->
        {:noreply, push_navigate(socket, to: ~p"/projects/#{socket.assigns.project.id}/edit")}

      {:error, _reason} ->
        {:noreply, assign(socket, :notice, gettext("share.join.join_failed"))}
    end
  end

  # The public/embed view reuses the editor's client hooks (CodeMirror, Preview),
  # which push compile/outline/save events back to the LiveView. This view is
  # read-only and compiles entirely client-side, so there is no server state to
  # update — we accept and ignore them. Without this clause, the first
  # `update_preview` push would crash the LiveView (undefined handle_event/3).
  # It also swallows join/fork clicks whose policy guard above didn't match.
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

  defp copy_name(name), do: gettext("share.join.copy_of", name: name)

  defp project_sources(files) do
    files
    |> Enum.filter(&Files.editable_file?/1)
    |> Enum.map(fn f ->
      %{path: f.path, content: f.content || "", language: Files.editor_language(f.path)}
    end)
  end
end
