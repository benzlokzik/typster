defmodule TypsterWeb.EditorLive.Index do
  use TypsterWeb, :live_view

  alias Typster.Assets
  alias Typster.Files
  alias Typster.Projects
  alias Typster.Revisions

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
     |> assign(:content, if(main_file, do: main_file.content || "", else: ""))
     |> assign(:editor_language, editor_language(main_file))
     |> assign(:project_sources, project_sources(file_tree))
     |> assign(:project_assets, project_assets(assets))
     |> assign(:save_status, "saved")
     |> assign(:preview_stats, nil)
     |> assign(:preview_error, nil)
     |> assign(:preview_compiling, false)
     |> assign(:creating?, false)
     |> assign(:new_file_name, "")
     |> assign(:new_file_suggestions, [])
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
    {:noreply,
     assign(socket,
       preview_stats: %{ms: params["ms"], pages: params["pages"]},
       preview_compiling: false,
       preview_error: nil
     )}
  end

  @impl true
  def handle_event("preview_error", %{"message" => message}, socket) do
    {:noreply, assign(socket, preview_error: message, preview_compiling: false)}
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
       |> assign(:current_file, file)
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

    {:noreply, assign(socket, :collapsed_dirs, collapsed)}
  end

  @impl true
  def handle_event("new_file", _params, socket) do
    {:noreply,
     socket
     |> assign(:creating?, true)
     |> assign(:new_file_name, "")
     |> assign(:new_file_suggestions, [])}
  end

  @impl true
  def handle_event("cancel_new_file", _params, socket) do
    {:noreply, assign(socket, creating?: false, new_file_name: "", new_file_suggestions: [])}
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
    path = Files.resolve_new_file_path(socket.assigns.file_tree, typed)

    cond do
      not Files.editable_file?(path) ->
        {:noreply, put_flash(socket, :error, gettext("editor.flash.unsupported_file"))}

      path_taken?(socket.assigns.file_tree, path) ->
        # Keep the draft open with what was typed so the name can be fixed.
        {:noreply,
         socket
         |> assign(:new_file_name, typed)
         |> assign(
           :new_file_suggestions,
           Files.new_file_suggestions(socket.assigns.file_tree, typed)
         )
         |> put_flash(:error, gettext("editor.flash.file_exists"))}

      true ->
        create_text_file(socket, path, default_file_content(path))
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

    current = socket.assigns.current_file
    was_open? = current && current.id == file.id
    next_file = if was_open?, do: initial_file(file_tree), else: current

    socket =
      socket
      |> assign(:file_tree, file_tree)
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

  defp pinned_files(file_tree), do: Enum.filter(file_tree, & &1.pinned)
  defp unpinned_files(file_tree), do: Enum.reject(file_tree, & &1.pinned)

  # Hierarchical section numbers, with the level-1 title left unnumbered and
  # numbering starting at level 2 (1, 2, 2.1, …) per the OutlineV2 design.
  defp section_number(1, _counters), do: {"", %{}}

  defp section_number(level, counters) do
    counters =
      counters
      |> Map.update(level, 1, &(&1 + 1))
      |> Map.reject(fn {l, _} -> l > level end)

    num = 2..level |> Enum.map(&Map.get(counters, &1, 1)) |> Enum.join(".")
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
