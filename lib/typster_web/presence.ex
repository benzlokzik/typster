defmodule TypsterWeb.Presence do
  @moduledoc """
  Tracks live collaborators inside the editor via `Phoenix.Presence`.

  Each project has its own presence topic (`editor:<project_id>`). When a user
  opens the editor, `track_user/3` records a small meta payload (display name,
  initials, and a deterministic color) so the UI can render avatar chips for
  everyone currently present without re-loading user records.
  """

  use Phoenix.Presence,
    otp_app: :typster,
    pubsub_server: Typster.PubSub

  require Logger

  # A small, fixed palette of pleasant hex colors. A user is mapped to one of
  # these deterministically from their id, so the same user always renders with
  # the same color across sessions and clients.
  @palette ~w(#6366f1 #8b5cf6 #0ea5e9 #10b981 #f43f5e #f59e0b)

  @doc """
  Returns the presence topic for the given project id.

  Accepts a binary id or any struct/value with an `id` we can stringify.
  """
  def topic(project_id) when is_binary(project_id), do: "editor:" <> project_id
  def topic(%{id: id}), do: topic(to_string(id))
  def topic(project_id), do: topic(to_string(project_id))

  @doc """
  Tracks `user` as present in the given project's editor topic.

  The presence key is the user's id, so a user opening multiple tabs collapses
  to a single collaborator entry.
  """
  def track_user(pid_or_socket, project_id, user) do
    track(pid_or_socket, topic(project_id), user.id, %{
      user_id: user.id,
      name: display_name(user),
      initials: initials(user),
      color: color_for(user.id),
      online_at: System.system_time(:second)
    })
  rescue
    ArgumentError ->
      Logger.warning(
        "TypsterWeb.Presence is not running — cannot track collaborator. " <>
          "Restart the server (a newly-added supervision child needs a fresh boot)."
      )

      {:error, :presence_unavailable}
  end

  @doc """
  Lists the distinct collaborators currently present in a project.

  Returns one `%{user_id, name, initials, color}` map per present user (taking
  the first meta per key), excluding `exclude_user_id` when given, sorted by
  name.
  """
  def list_collaborators(project_id, exclude_user_id \\ nil) do
    project_id
    |> topic()
    |> safe_list()
    |> Enum.map(fn {_key, %{metas: [meta | _]}} ->
      %{user_id: meta.user_id, name: meta.name, initials: meta.initials, color: meta.color}
    end)
    |> Enum.reject(&(&1.user_id == exclude_user_id))
    |> Enum.sort_by(& &1.name)
  end

  # Presence is a supervised core process, but if it is ever unavailable —
  # e.g. a dev server still running from before it was added to the supervision
  # tree (its ETS table never started) — degrade to "no collaborators" rather
  # than crashing the editor mount. A restart brings collaborators back.
  defp safe_list(topic) do
    list(topic)
  rescue
    ArgumentError ->
      Logger.warning(
        "TypsterWeb.Presence is not running — collaborators unavailable. " <>
          "Restart the server (a newly-added supervision child needs a fresh boot)."
      )

      %{}
  end

  defp display_name(user) do
    user.email
    |> local_part()
    |> String.capitalize()
  end

  defp initials(user) do
    user.email
    |> local_part()
    |> String.split(~r/[._-]+/, trim: true)
    |> Enum.map(&String.first/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.take(2)
    |> Enum.map_join(&String.upcase/1)
    |> case do
      "" -> "?"
      initials -> initials
    end
  end

  defp color_for(user_id) do
    index = :erlang.phash2(user_id, length(@palette))
    Enum.at(@palette, index)
  end

  defp local_part(email) do
    email
    |> to_string()
    |> String.split("@", parts: 2)
    |> List.first()
    |> Kernel.||("")
  end
end
