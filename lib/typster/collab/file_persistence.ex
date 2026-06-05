defmodule Typster.Collab.FilePersistence do
  @moduledoc """
  Seeds a freshly-started `Yex.Sync.SharedDoc` with the file's saved content so
  the first editor to open it (and anyone who joins later) sees the document.

  The shared text is the Y.Text named `"content"` — the client binds the same
  name via `y-codemirror.next`. We only implement `bind/3` (the load side):
  saving back to the `files` table is done by the editor's existing autosave,
  which fires for every synced keystroke. When the room empties the process
  exits and is re-seeded from the (now up-to-date) file on the next open.
  """

  @behaviour Yex.Sync.SharedDoc.PersistenceBehaviour

  alias Typster.Projects.File
  alias Typster.Repo
  alias Yex.{Doc, Text}

  @impl true
  def bind(file_id, _doc_name, doc) do
    case load_content(file_id) do
      content when is_binary(content) and content != "" ->
        # `Text.insert/3` transacts internally — do NOT wrap it in another
        # `Doc.transaction/2`, or the nested transaction deadlocks.
        doc
        |> Doc.get_text("content")
        |> Text.insert(0, content)

      _ ->
        :ok
    end

    file_id
  end

  @impl true
  def unbind(_state, _doc_name, _doc), do: :ok

  defp load_content(file_id) do
    case Repo.get(File, file_id) do
      %File{content: content} -> content
      _ -> nil
    end
  end
end
