defmodule TypsterWeb.EditorLive.Index do
  use TypsterWeb, :live_view

  alias Typster.Assets
  alias Typster.Files
  alias Typster.Projects
  alias Typster.Revisions
  alias Typster.Templates

  @impl true
  def mount(%{"id" => project_id}, _session, socket) do
    scope = socket.assigns.current_scope
    project = Projects.get_project!(scope, project_id)
    file_tree = Files.get_file_tree(scope, project_id)
    assets = Assets.list_assets(scope, project_id)
    main_file = initial_file(file_tree)

    {:ok,
     socket
     |> assign(:project, project)
     |> assign(:file_tree, file_tree)
     |> assign(:assets, assets)
     |> assign(:current_file, main_file)
     |> assign(:active_dir, file_dir(main_file))
     |> assign(:create_dir, "")
     |> assign(:open_file_ids, if(main_file, do: [main_file.id], else: []))
     |> assign(:content, if(main_file, do: main_file.content || "", else: ""))
     |> assign(:editor_language, editor_language(main_file))
     |> assign(:project_sources, project_sources(file_tree))
     |> assign(:project_assets, project_assets(assets))
     |> assign(:save_status, "saved")
     |> assign(:preview_stats, nil)
     |> assign(:preview_error, nil)
     |> assign(:preview_error_count, 0)
     |> assign(:preview_compiling, false)
     |> assign(:diagnostics, [])
     |> assign(:compile_log, [])
     |> assign(:drawer_open, false)
     |> assign(:drawer_tab, "log")
     |> assign(:creating?, false)
     |> assign(:new_kind, :file)
     |> assign(:new_file_name, "")
     |> assign(:new_file_suggestions, [])
     |> assign(:template_content, nil)
     |> assign(:templates, Templates.list_templates(scope))
     |> assign(:file_view_mode, :tree)
     |> assign(:collapsed_dirs, MapSet.new())
     |> assign(:show_palette, false)
     |> assign(:palette_query, "")
     |> stream(:outline, [])
     |> assign(:outline_count, 0)
     |> assign(:page_title, project.name)
     |> allow_upload(:asset,
       accept: ~w(.pdf .png .jpg .jpeg .svg .webp .ttf .otf .woff .woff2),
       max_entries: 5,
       max_file_size: 20_000_000
     )
     |> allow_upload(:template,
       accept: :any,
       max_entries: 1,
       max_file_size: 2_000_000,
       auto_upload: true,
       progress: &handle_template_progress/3
     )
     |> allow_upload(:dropped,
       accept: :any,
       max_entries: 10,
       max_file_size: 20_000_000,
       auto_upload: true,
       progress: &handle_dropped_progress/3
     )}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, assign(socket, :page_title, socket.assigns.project.name)}
  end

  @impl true
  def handle_event("save_started", _params, socket) do
    {:noreply, assign(socket, :save_status, "saving")}
  end

  @impl true
  def handle_event("autosave", %{"file_id" => file_id, "content" => content}, socket) do
    scope = socket.assigns.current_scope
    file = Files.get_file!(scope, file_id)

    if socket.assigns.current_file && socket.assigns.current_file.id == file.id do
      case Files.update_file_content(scope, file, content) do
        {:ok, updated_file} ->
          Revisions.create_revision(scope, file_id, content)
          file_tree = Files.get_file_tree(scope, socket.assigns.project.id)

          {:noreply,
           socket
           |> assign(:current_file, updated_file)
           |> assign(:file_tree, file_tree)
           |> assign(:project_sources, project_sources(file_tree))
           |> assign(:content, content)
           |> assign(:save_status, "saved")}

        {:error, _changeset} ->
          {:noreply, assign(socket, :save_status, "error")}
      end
    else
      {:noreply, assign(socket, :save_status, "error")}
    end
  end

  @impl true
  def handle_event("compile_started", _params, socket) do
    {:noreply, assign(socket, preview_compiling: true, preview_error: nil)}
  end

  @impl true
  def handle_event("update_preview", params, socket) do
    pages = params["pages"] || 1
    sources = length(socket.assigns.project_sources)

    log =
      log_entry(:ok, "compiled · #{params["ms"]}ms · #{pages} page(s) · #{sources} sources")

    {:noreply,
     socket
     |> assign(:preview_stats, %{ms: params["ms"], pages: pages})
     |> assign(:preview_compiling, false)
     |> assign(:preview_error, nil)
     |> assign(:preview_error_count, 0)
     |> assign(:diagnostics, [])
     |> push_log(log)}
  end

  @impl true
  def handle_event("preview_error", %{"message" => message} = params, socket) do
    diagnostics = normalize_diagnostics(params["diagnostics"])
    errors = params["errors"] || length(diagnostics)
    warnings = params["warnings"] || 0

    {:noreply,
     socket
     |> assign(:preview_error, message)
     |> assign(:preview_error_count, errors)
     |> assign(:preview_compiling, false)
     |> assign(:diagnostics, diagnostics)
     |> push_log(log_entry(:error, error_log_text(errors, warnings)))}
  end

  @impl true
  def handle_event("toggle_drawer", _params, socket) do
    {:noreply, assign(socket, :drawer_open, not socket.assigns.drawer_open)}
  end

  @impl true
  def handle_event("set_drawer_tab", %{"tab" => tab}, socket) do
    tab = if tab == "problems", do: "problems", else: "log"
    {:noreply, assign(socket, drawer_open: true, drawer_tab: tab)}
  end

  @impl true
  def handle_event("clear_log", _params, socket) do
    {:noreply, assign(socket, :compile_log, [])}
  end

  @impl true
  def handle_event("outline_parsed", %{"items" => items}, socket) do
    {outline, _counters} =
      items
      |> Enum.with_index()
      |> Enum.map_reduce(%{}, fn {item, idx}, counters ->
        level = item["level"] || 1
        {num, counters} = section_number(level, counters)

        node = %{
          id: "outline-#{idx}",
          level: level,
          num: num,
          text: item["text"] || "",
          line: item["line"] || 1
        }

        {node, counters}
      end)

    {:noreply,
     socket
     |> assign(:outline_count, length(outline))
     |> stream(:outline, outline, reset: true)}
  end

  @impl true
  def handle_event("open_palette", _params, socket) do
    {:noreply, assign(socket, show_palette: true, palette_query: "")}
  end

  @impl true
  def handle_event("close_palette", _params, socket) do
    {:noreply, assign(socket, :show_palette, false)}
  end

  @impl true
  def handle_event("filter_palette", %{"value" => query}, socket) do
    {:noreply, assign(socket, :palette_query, query)}
  end

  @impl true
  def handle_event("select_file", %{"file-id" => file_id}, socket) do
    scope = socket.assigns.current_scope
    file = Files.get_file!(scope, file_id)

    if Files.editable_file?(file) do
      {:noreply,
       socket
       |> open_tab(file_id)
       |> assign(:current_file, file)
       |> assign(:active_dir, file_dir(file))
       |> assign(:content, file.content || "")
       |> assign(:editor_language, editor_language(file))
       |> assign(:save_status, "saved")
       |> push_event("file_changed", %{
         file_id: file_id,
         content: file.content || "",
         language: editor_language(file)
       })
       |> push_event("content_updated", %{content: file.content || ""})}
    else
      {:noreply, put_flash(socket, :error, gettext("editor.flash.binary_asset"))}
    end
  end

  @impl true
  def handle_event("close_tab", %{"id" => file_id}, socket) do
    remaining = Enum.reject(socket.assigns.open_file_ids, &(&1 == file_id))
    socket = assign(socket, :open_file_ids, remaining)
    current = socket.assigns.current_file

    if current && current.id == file_id do
      # Activate the nearest remaining tab, or clear the editor when none remain.
      case remaining |> List.last() |> next_open_file(socket) do
        nil ->
          {:noreply,
           socket
           |> assign(:current_file, nil)
           |> assign(:content, "")
           |> assign(:editor_language, "plain")
           |> push_event("file_changed", %{file_id: nil, content: "", language: "plain"})
           |> push_event("content_updated", %{content: ""})}

        file ->
          {:noreply,
           socket
           |> assign(:current_file, file)
           |> assign(:content, file.content || "")
           |> assign(:editor_language, editor_language(file))
           |> push_event("file_changed", %{
             file_id: file.id,
             content: file.content || "",
             language: editor_language(file)
           })
           |> push_event("content_updated", %{content: file.content || ""})}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("set_file_view", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, :file_view_mode, TypsterWeb.FileTree.mode(mode))}
  end

  @impl true
  def handle_event("toggle_dir", %{"path" => path}, socket) do
    collapsed = socket.assigns.collapsed_dirs

    collapsed =
      if MapSet.member?(collapsed, path),
        do: MapSet.delete(collapsed, path),
        else: MapSet.put(collapsed, path)

    # Clicking a folder makes it the active directory for new files/folders.
    {:noreply, socket |> assign(:collapsed_dirs, collapsed) |> assign(:active_dir, path)}
  end

  @impl true
  def handle_event("new_file", _params, socket) do
    {:noreply, start_create(socket, :file)}
  end

  @impl true
  def handle_event("new_folder", _params, socket) do
    {:noreply, start_create(socket, :folder)}
  end

  @impl true
  def handle_event("cancel_new_file", _params, socket) do
    {:noreply,
     socket
     |> assign(creating?: false, new_file_name: "", new_file_suggestions: [])
     |> assign(:new_kind, :file)
     |> assign(:template_content, nil)}
  end

  @impl true
  def handle_event("validate_template", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("validate_dropped", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("use_template", %{"id" => id}, socket) do
    template = Templates.get_template!(socket.assigns.current_scope, id)
    stem = Path.rootname(template.name)

    {:noreply,
     socket
     |> assign(:creating?, true)
     |> assign(:new_kind, :file)
     |> assign(:create_dir, socket.assigns.active_dir)
     |> assign(:new_file_name, stem)
     |> assign(
       :new_file_suggestions,
       Files.new_file_suggestions(socket.assigns.file_tree, stem)
     )
     |> assign(:template_content, template.content || "")}
  end

  @impl true
  def handle_event("delete_template", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    template = Templates.get_template!(scope, id)
    {:ok, _} = Templates.delete_template(scope, template)
    {:noreply, assign(socket, :templates, Templates.list_templates(scope))}
  end

  @impl true
  def handle_event("create_folder_from_dialog", %{"path" => typed}, socket) do
    name = typed |> String.trim() |> String.trim("/")
    folder = socket.assigns.create_dir |> join_dir(name) |> String.trim("/")

    cond do
      name == "" ->
        {:noreply, socket}

      folder_taken?(socket.assigns.file_tree, folder) ->
        {:noreply,
         socket
         |> assign(:new_file_name, typed)
         |> put_flash(:error, gettext("editor.flash.file_exists"))}

      true ->
        # Folders are path-derived, so a new folder is seeded with a starter file
        # using the project's majority source type.
        ext = Files.majority_source_extension(socket.assigns.file_tree)
        path = "#{folder}/untitled#{ext}"

        socket
        |> assign(creating?: false, new_kind: :file, new_file_name: "", new_file_suggestions: [])
        |> create_text_file(path, default_file_content(path))
    end
  end

  @impl true
  def handle_event("suggest_new_file", %{"path" => name}, socket) do
    suggestions = Files.new_file_suggestions(socket.assigns.file_tree, name)

    {:noreply,
     socket
     |> assign(:new_file_name, name)
     |> assign(:new_file_suggestions, suggestions)}
  end

  @impl true
  def handle_event("create_file_from_dialog", %{"path" => typed}, socket) do
    name = String.trim(typed)
    full = join_dir(socket.assigns.create_dir, name)
    path = Files.resolve_new_file_path(socket.assigns.file_tree, full)

    cond do
      name == "" ->
        {:noreply, socket}

      not Files.editable_file?(path) ->
        {:noreply, put_flash(socket, :error, gettext("editor.flash.unsupported_file"))}

      path_taken?(socket.assigns.file_tree, path) ->
        # Keep the draft open with the typed name (folder prefix shown separately).
        {:noreply,
         socket
         |> assign(:new_file_name, name)
         |> assign(
           :new_file_suggestions,
           Files.new_file_suggestions(socket.assigns.file_tree, name)
         )
         |> put_flash(:error, gettext("editor.flash.file_exists"))}

      true ->
        content = socket.assigns.template_content || default_file_content(path)
        create_text_file(assign(socket, :template_content, nil), path, content)
    end
  end

  @impl true
  def handle_event("create_file", %{"path" => path, "content" => content}, socket) do
    if Files.editable_file?(path) do
      create_text_file(socket, path, content)
    else
      {:noreply, put_flash(socket, :error, gettext("editor.flash.unsupported_file"))}
    end
  end

  @impl true
  def handle_event("toggle_pin", %{"id" => file_id}, socket) do
    scope = socket.assigns.current_scope
    file = Files.get_file!(scope, file_id)
    {:ok, _} = Files.set_pinned(scope, file, not file.pinned)
    file_tree = Files.get_file_tree(scope, socket.assigns.project.id)

    {:noreply,
     socket
     |> assign(:file_tree, file_tree)
     |> assign(:project_sources, project_sources(file_tree))}
  end

  @impl true
  def handle_event("delete_file", %{"id" => file_id}, socket) do
    scope = socket.assigns.current_scope
    file = Files.get_file!(scope, file_id)
    {:ok, _} = Files.delete_file(scope, file)
    file_tree = Files.get_file_tree(scope, socket.assigns.project.id)

    open_ids = Enum.reject(socket.assigns.open_file_ids, &(&1 == file.id))
    current = socket.assigns.current_file
    was_open? = current && current.id == file.id

    next_file =
      cond do
        not was_open? -> current
        open_ids != [] -> Enum.find(file_tree, &(&1.id == List.last(open_ids)))
        true -> initial_file(file_tree)
      end

    socket =
      socket
      |> assign(:file_tree, file_tree)
      |> assign(:open_file_ids, open_ids)
      |> assign(:project_sources, project_sources(file_tree))
      |> assign(:current_file, next_file)
      |> put_flash(:info, gettext("editor.flash.file_deleted"))

    if was_open? do
      content = if next_file, do: next_file.content || "", else: ""

      {:noreply,
       socket
       |> assign(:content, content)
       |> assign(:editor_language, editor_language(next_file))
       |> push_event("file_changed", %{
         file_id: next_file && next_file.id,
         content: content,
         language: editor_language(next_file)
       })
       |> push_event("content_updated", %{content: content})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete_asset", %{"id" => asset_id}, socket) do
    scope = socket.assigns.current_scope
    asset = Assets.get_asset!(scope, asset_id)
    {:ok, _} = Assets.delete_asset(scope, asset)
    assets = Assets.list_assets(scope, socket.assigns.project.id)

    {:noreply,
     socket
     |> assign(:assets, assets)
     |> assign(:project_assets, project_assets(assets))
     |> put_flash(:info, gettext("editor.flash.asset_deleted"))}
  end

  @impl true
  def handle_event("validate_upload", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("save_upload", _params, socket) do
    scope = socket.assigns.current_scope
    project_id = socket.assigns.project.id

    results =
      consume_uploaded_entries(socket, :asset, fn %{path: path}, entry ->
        Assets.upload_entry(scope, project_id, %{
          path: path,
          client_name: entry.client_name,
          client_type: entry.client_type
        })
      end)

    case Enum.find(results, &match?({:error, _}, &1)) do
      nil ->
        assets = Assets.list_assets(scope, project_id)

        {:noreply,
         socket
         |> assign(:assets, assets)
         |> assign(:project_assets, project_assets(assets))
         |> put_flash(:info, gettext("editor.flash.asset_uploaded"))}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, gettext("editor.flash.asset_upload_failed"))}
    end
  end

  defp create_text_file(socket, path, content) do
    scope = socket.assigns.current_scope

    case Files.create_file(scope, socket.assigns.project.id, %{path: path, content: content}) do
      {:ok, file} ->
        file_tree = Files.get_file_tree(scope, socket.assigns.project.id)

        {:noreply,
         socket
         |> assign(creating?: false, new_file_name: "", new_file_suggestions: [])
         |> assign(:file_tree, file_tree)
         |> assign(:project_sources, project_sources(file_tree))
         |> open_tab(file.id)
         |> assign(:current_file, file)
         |> assign(:content, content)
         |> assign(:editor_language, editor_language(file))
         |> push_event("file_changed", %{
           file_id: file.id,
           content: content,
           language: editor_language(file)
         })
         |> push_event("content_updated", %{content: content})}

      {:error, changeset} ->
        message =
          if path_taken_error?(changeset),
            do: gettext("editor.flash.file_exists"),
            else: gettext("editor.flash.create_failed")

        {:noreply, put_flash(socket, :error, message)}
    end
  end

  defp path_taken?(file_tree, path), do: Enum.any?(file_tree, &(&1.path == path))

  defp folder_taken?(file_tree, folder),
    do: Enum.any?(file_tree, &String.starts_with?(&1.path, folder <> "/"))

  defp path_taken_error?(changeset) do
    Enum.any?(changeset.errors, fn {field, _} -> field == :path end)
  end

  defp default_file_content(path) do
    case path |> Path.extname() |> String.downcase() do
      ".typ" ->
        "#set page(margin: 2cm)\n\n= Introduction\n\nHello from Typster!"

      ".tex" ->
        "\\documentclass{article}\n\n\\begin{document}\n\n\\section{Introduction}\n\n\\end{document}\n"

      _ ->
        ""
    end
  end

  # Glyph + color bucket for the live file-type chip in the inline create row.
  defp draft_chip_ext(name, suggestions) do
    cond do
      ext_label(name) != "" -> ext_label(name)
      suggestions != [] -> ext_label(hd(suggestions))
      true -> "typ"
    end
  end

  # Extension that pressing Enter will append, or `nil` when the name already
  # carries one (so the "+ .ext" hint pill stays hidden).
  defp draft_hint(name, suggestions) do
    if ext_label(String.trim(name)) == "" and suggestions != [] do
      Path.extname(hd(suggestions))
    end
  end

  defp ext_label(path),
    do: path |> Path.extname() |> String.trim_leading(".") |> String.downcase()

  defp chip_glyph(ext) do
    case ext do
      "typ" -> "T"
      "bib" -> "B"
      "md" -> "M"
      e when e in ~w(tex latex sty cls) -> "L"
      e -> e |> String.first() |> Kernel.||("·") |> String.upcase()
    end
  end

  defp initial_file(file_tree) do
    Enum.find(file_tree, &(&1.path == "main.typ")) ||
      Enum.find(file_tree, &Files.editable_file?/1)
  end

  defp editor_language(nil), do: "plain"
  defp editor_language(file), do: Files.editor_language(file.path)

  defp palette_match?(query, label) do
    query = String.trim(query || "")
    query == "" or String.contains?(String.downcase(label), String.downcase(query))
  end

  defp palette_files(file_tree, query) do
    Enum.filter(file_tree, &(Files.editable_file?(&1) and palette_match?(query, &1.path)))
  end

  defp save_status_label("saved"), do: gettext("editor.status.saved")
  defp save_status_label("saving"), do: gettext("editor.status.saving")
  defp save_status_label("error"), do: gettext("editor.status.error")
  defp save_status_label(status), do: status

  # Auto-save a dropped/selected template file once its bytes finish uploading.
  defp handle_template_progress(:template, entry, socket) do
    if entry.done? do
      scope = socket.assigns.current_scope

      consume_uploaded_entries(socket, :template, fn %{path: path}, e ->
        {:ok, Templates.create_template(scope, %{name: e.client_name, content: File.read!(path)})}
      end)

      {:noreply,
       socket
       |> assign(:templates, Templates.list_templates(scope))
       |> put_flash(:info, gettext("editor.flash.template_saved"))}
    else
      {:noreply, socket}
    end
  end

  # Route a file dropped onto the editor/assets: asset types upload as assets,
  # editable types become new files, anything else is rejected.
  defp handle_dropped_progress(:dropped, entry, socket) do
    if entry.done?, do: {:noreply, consume_dropped(socket)}, else: {:noreply, socket}
  end

  defp consume_dropped(socket) do
    scope = socket.assigns.current_scope
    project_id = socket.assigns.project.id

    results =
      consume_uploaded_entries(socket, :dropped, fn %{path: tmp}, entry ->
        name = entry.client_name

        cond do
          Files.asset_file?(name) ->
            Assets.upload_entry(scope, project_id, %{
              path: tmp,
              client_name: name,
              client_type: entry.client_type
            })

            {:ok, :asset}

          Files.editable_file?(name) ->
            Files.create_file(scope, project_id, %{path: name, content: File.read!(tmp)})
            {:ok, :file}

          true ->
            {:ok, {:unsupported, name}}
        end
      end)

    file_tree = Files.get_file_tree(scope, project_id)
    assets = Assets.list_assets(scope, project_id)
    unsupported = Enum.any?(results, &match?({:unsupported, _}, &1))

    socket
    |> assign(:file_tree, file_tree)
    |> assign(:project_sources, project_sources(file_tree))
    |> assign(:assets, assets)
    |> assign(:project_assets, project_assets(assets))
    |> then(fn s ->
      if unsupported,
        do: put_flash(s, :error, gettext("editor.flash.unsupported_file")),
        else: put_flash(s, :info, gettext("editor.flash.dropped_added"))
    end)
  end

  # The directory a file lives in ("" for project root), used as the target
  # folder when creating new files/folders.
  defp file_dir(nil), do: ""

  defp file_dir(%{path: path}) do
    case Path.dirname(path) do
      "." -> ""
      dir -> dir
    end
  end

  # Open the inline draft targeting the active folder (shown as a static prefix,
  # not editable text) and expand that folder so the result is visible.
  defp start_create(socket, kind) do
    active_dir = socket.assigns.active_dir

    socket
    |> assign(:creating?, true)
    |> assign(:new_kind, kind)
    |> assign(:create_dir, active_dir)
    |> assign(:new_file_name, "")
    |> assign(:new_file_suggestions, [])
    |> assign(:template_content, nil)
    |> assign(:collapsed_dirs, MapSet.delete(socket.assigns.collapsed_dirs, active_dir))
  end

  defp join_dir("", name), do: name
  defp join_dir(dir, name), do: "#{dir}/#{name}"

  # Breadcrumb segments from the active file's path; the filename is `last`.
  defp path_segments(nil), do: []

  defp path_segments(%{path: path}) do
    parts = String.split(path, "/")
    count = length(parts)
    parts |> Enum.with_index(1) |> Enum.map(fn {p, i} -> %{name: p, last: i == count} end)
  end

  # Append a file id to the open-tabs list (keeping order, no duplicates).
  defp open_tab(socket, file_id) do
    ids = socket.assigns.open_file_ids
    if file_id in ids, do: socket, else: assign(socket, :open_file_ids, ids ++ [file_id])
  end

  defp next_open_file(nil, _socket), do: nil

  defp next_open_file(file_id, socket),
    do: Enum.find(socket.assigns.file_tree, &(&1.id == file_id))

  # Open files as structs, in tab order, dropping any that no longer exist.
  defp open_tabs(file_tree, open_file_ids) do
    Enum.flat_map(open_file_ids, fn id ->
      case Enum.find(file_tree, &(&1.id == id)),
        do: (
          nil -> []
          file -> [file]
        )
    end)
  end

  # Split a path into {folder_or_nil, filename} for tab/crumb labels.
  defp split_path(path) do
    case Path.dirname(path) do
      "." -> {nil, path}
      dir -> {dir, Path.basename(path)}
    end
  end

  # ── Compile log + diagnostics ─────────────────────────────────────────────
  defp normalize_diagnostics(nil), do: []

  defp normalize_diagnostics(list) when is_list(list) do
    Enum.map(list, fn d ->
      loc = d["location"] || %{}

      %{
        severity: if(d["severity"] == "warning", do: "warning", else: "error"),
        file: loc["file"],
        line: loc["line"],
        col: loc["col"],
        message: d["message"] || ""
      }
    end)
  end

  defp normalize_diagnostics(_), do: []

  defp log_entry(kind, text) do
    %{kind: kind, text: text, at: Calendar.strftime(Time.utc_now(), "%H:%M:%S")}
  end

  # Keep the most recent 40 entries so the log can't grow unbounded.
  defp push_log(socket, entry) do
    assign(socket, :compile_log, Enum.take(socket.assigns.compile_log ++ [entry], -40))
  end

  defp error_log_text(errors, warnings) do
    parts =
      [errors > 0 && ngettext("%{count} error", "%{count} errors", errors)]
      |> Enum.concat([
        warnings > 0 && ngettext("%{count} warning", "%{count} warnings", warnings)
      ])
      |> Enum.filter(& &1)

    if parts == [], do: gettext("editor.compile_failed"), else: Enum.join(parts, " · ")
  end

  defp first_error_line(diagnostics) do
    Enum.find_value(diagnostics, fn d -> d.line end)
  end

  defp pinned_files(file_tree), do: Enum.filter(file_tree, & &1.pinned)

  # Hierarchical section numbers, with the level-1 title left unnumbered and
  # numbering starting at level 2 (1, 2, 2.1, …) per the OutlineV2 design.
  defp section_number(1, _counters), do: {"", %{}}

  defp section_number(level, counters) do
    counters =
      counters
      |> Map.update(level, 1, &(&1 + 1))
      |> Map.reject(fn {l, _} -> l > level end)

    num = Enum.map_join(2..level, ".", &Map.get(counters, &1, 1))
    {num, counters}
  end

  defp project_sources(file_tree) do
    file_tree
    |> Enum.filter(&Files.editable_file?/1)
    |> Enum.map(fn file ->
      %{path: file.path, content: file.content || "", language: Files.editor_language(file.path)}
    end)
  end

  defp project_assets(assets) do
    Enum.map(assets, fn asset ->
      %{
        filename: asset.filename,
        reference_path: Assets.reference_path(asset),
        content_type: asset.content_type,
        size: asset.size
      }
    end)
  end
end
