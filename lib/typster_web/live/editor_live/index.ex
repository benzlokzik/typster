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
     |> assign(:show_new_file_dialog, false)
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
  def handle_event(
        "update_preview",
        %{"source_count" => source_count, "asset_count" => asset_count},
        socket
      ) do
    {:noreply,
     assign(socket,
       preview_stats: %{source_count: source_count, asset_count: asset_count},
       preview_error: nil
     )}
  end

  @impl true
  def handle_event("preview_error", %{"message" => message}, socket) do
    {:noreply, assign(socket, :preview_error, message)}
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
  def handle_event("new_file", _params, socket) do
    {:noreply, assign(socket, :show_new_file_dialog, true)}
  end

  @impl true
  def handle_event("close_file_dialog", _params, socket) do
    {:noreply, assign(socket, :show_new_file_dialog, false)}
  end

  @impl true
  def handle_event("create_file_from_dialog", %{"path" => path}, socket) do
    if Files.editable_file?(path) do
      default_content = default_file_content(path)
      socket = assign(socket, :show_new_file_dialog, false)
      create_text_file(socket, path, default_content)
    else
      {:noreply, put_flash(socket, :error, gettext("editor.flash.unsupported_file"))}
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

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, gettext("editor.flash.create_failed"))}
    end
  end

  defp default_file_content(path) do
    case Path.extname(path) do
      ".typ" -> "#set page(margin: 2cm)\n\n= Introduction\n\nHello from Typster!"
      _ -> ""
    end
  end

  defp initial_file(file_tree) do
    Enum.find(file_tree, &(&1.path == "main.typ")) ||
      Enum.find(file_tree, &Files.editable_file?/1)
  end

  defp editor_language(nil), do: "plain"
  defp editor_language(file), do: Files.editor_language(file.path)

  defp save_status_label("saved"), do: gettext("editor.status.saved")
  defp save_status_label("saving"), do: gettext("editor.status.saving")
  defp save_status_label("error"), do: gettext("editor.status.error")
  defp save_status_label(status), do: status

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
