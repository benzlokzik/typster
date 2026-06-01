defmodule TypsterWeb.ProjectLive.Show do
  use TypsterWeb, :live_view

  alias Typster.Projects
  alias Typster.Files
  alias Typster.Assets

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    scope = socket.assigns.current_scope
    project = Projects.get_editable_project!(scope, id)
    file_tree = Files.get_file_tree(scope, id)
    assets = Assets.list_assets(scope, id)

    {:ok,
     socket
     |> assign(:project, project)
     |> assign(:file_tree, file_tree)
     |> assign(:assets, assets)}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    {:noreply,
     socket
     |> assign(:page_title, socket.assigns.project.name)
     |> assign(:project, Projects.get_editable_project!(socket.assigns.current_scope, id))}
  end

  @impl true
  def handle_event("delete_file", %{"id" => file_id}, socket) do
    scope = socket.assigns.current_scope
    file = Files.get_file!(scope, file_id)
    {:ok, _} = Files.delete_file(scope, file)

    file_tree = Files.get_file_tree(scope, socket.assigns.project.id)

    {:noreply, assign(socket, :file_tree, file_tree)}
  end
end
