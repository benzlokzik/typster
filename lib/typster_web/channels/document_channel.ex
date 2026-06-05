defmodule TypsterWeb.DocumentChannel do
  @moduledoc """
  Yjs sync channel for collaborative file editing (`doc:<file_id>`).

  Relays the Yjs sync protocol between the `y-phoenix-channel` client provider
  and the file's server-side `Yex.Sync.SharedDoc`. Authorization reuses the
  editor's content gate (`Files.get_file!/2`, owner-or-accepted-collaborator),
  so only people who can edit the file can join its document.
  """
  use Phoenix.Channel

  alias Typster.Accounts.Scope
  alias Typster.Files
  alias Yex.Sync.SharedDoc

  @impl true
  def join("doc:" <> file_id, _params, socket) do
    if can_edit?(socket.assigns[:user], file_id) do
      {:ok, pid} = Typster.Collab.get_or_start_doc(file_id)
      SharedDoc.observe(pid)
      ref = Process.monitor(pid)
      {:ok, assign(socket, doc_pid: pid, doc_ref: ref)}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  # Initial sync handshake (client → server state vector).
  @impl true
  def handle_in("yjs_sync", {:binary, chunk}, socket) do
    SharedDoc.start_sync(socket.assigns.doc_pid, chunk)
    {:noreply, socket}
  end

  # Ongoing document + awareness updates.
  def handle_in("yjs", {:binary, chunk}, socket) do
    SharedDoc.send_yjs_message(socket.assigns.doc_pid, chunk)
    {:noreply, socket}
  end

  # The SharedDoc pushes sync replies / remote updates to its observers.
  @impl true
  def handle_info({:yjs, message, _proc}, socket) do
    push(socket, "yjs", {:binary, message})
    {:noreply, socket}
  end

  # The room process exited (e.g. everyone left) — tell the client to resync.
  def handle_info({:DOWN, ref, :process, _pid, _reason}, %{assigns: %{doc_ref: ref}} = socket) do
    push(socket, "yjs_server_down", %{})
    {:stop, :normal, socket}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  defp can_edit?(nil, _file_id), do: false

  defp can_edit?(user, file_id) do
    Files.get_file!(Scope.for_user(user), file_id)
    true
  rescue
    Ecto.NoResultsError -> false
    Ecto.Query.CastError -> false
  end
end
