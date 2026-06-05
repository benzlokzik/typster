defmodule Typster.Collab do
  @moduledoc """
  Real-time collaborative editing backbone.

  Each open file gets one `Yex.Sync.SharedDoc` process — a server-authoritative
  Yjs document — started on demand, registered by file id, and supervised
  dynamically. `auto_exit: true` tears the process down when the last editor
  disconnects; it is re-seeded from the file's saved content on the next open.

  The channel (`TypsterWeb.DocumentChannel`) speaks the Yjs sync protocol to
  this process; persistence of the document text back to the `files` table is
  handled by the editor's existing autosave (every synced keystroke saves).
  """

  @registry Typster.Collab.Registry
  @supervisor Typster.Collab.DocSupervisor

  @doc "Returns the running SharedDoc pid for `file_id`, or `nil`."
  def whereis(file_id) do
    case Registry.lookup(@registry, file_id) do
      [{pid, _}] -> pid
      [] -> nil
    end
  end

  @doc """
  Returns the SharedDoc for `file_id`, starting it (seeded from the file's
  current content) if it isn't already running.
  """
  @spec get_or_start_doc(String.t()) :: {:ok, pid()} | {:error, term()}
  def get_or_start_doc(file_id) when is_binary(file_id) do
    case whereis(file_id) do
      nil -> start_doc(file_id)
      pid -> {:ok, pid}
    end
  end

  defp start_doc(file_id) do
    spec = %{
      id: {Yex.Sync.SharedDoc, file_id},
      start:
        {Yex.Sync.SharedDoc, :start_link,
         [
           [
             doc_name: file_id,
             persistence: {Typster.Collab.FilePersistence, file_id},
             auto_exit: true
           ],
           [name: {:via, Registry, {@registry, file_id}}]
         ]},
      restart: :temporary
    }

    case DynamicSupervisor.start_child(@supervisor, spec) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      other -> other
    end
  end
end
