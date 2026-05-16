defmodule TypsterWeb.ProjectLive.Index do
  use TypsterWeb, :live_view

  alias Typster.Projects

  @impl true
  def mount(_params, _session, socket) do
    projects = Projects.list_projects(socket.assigns.current_scope)

    {:ok,
     socket
     |> assign(:page_title, gettext("projects.index.title"))
     |> assign(:search, "")
     |> assign(:show_new_dialog, false)
     |> assign(:project_count, length(projects))
     |> stream(:projects, projects)}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    project = Projects.get_project!(socket.assigns.current_scope, id)
    {:ok, _} = Projects.delete_project(socket.assigns.current_scope, project)

    {:noreply,
     socket
     |> assign(:project_count, max(socket.assigns.project_count - 1, 0))
     |> stream_delete(:projects, project)}
  end

  @impl true
  def handle_event("new_project", _params, socket) do
    {:noreply, assign(socket, :show_new_dialog, true)}
  end

  @impl true
  def handle_event("close_dialog", _params, socket) do
    {:noreply, assign(socket, :show_new_dialog, false)}
  end

  @impl true
  def handle_event("create_project", %{"name" => name}, socket) do
    name = String.trim(name)

    case Projects.create_project(socket.assigns.current_scope, %{name: name}) do
      {:ok, project} ->
        {:noreply,
         socket
         |> assign(:show_new_dialog, false)
         |> assign(:project_count, socket.assigns.project_count + 1)
         |> stream_insert(:projects, project, at: -1)}

      {:error, _changeset} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("search", %{"value" => query}, socket) do
    projects = Projects.list_projects(socket.assigns.current_scope)

    filtered =
      if query == "" do
        projects
      else
        q = String.downcase(query)
        Enum.filter(projects, &String.contains?(String.downcase(&1.name), q))
      end

    {:noreply,
     socket
     |> assign(:search, query)
     |> assign(:project_count, length(filtered))
     |> stream(:projects, filtered, reset: true)}
  end
end
