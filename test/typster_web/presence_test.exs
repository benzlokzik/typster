defmodule TypsterWeb.PresenceTest do
  # async: false — Presence is a shared, app-started process so tracked entries
  # from concurrent tests could otherwise leak across topics.
  use ExUnit.Case, async: false

  alias Typster.Accounts.User
  alias TypsterWeb.Presence

  setup do
    # A unique project id per test keeps topics isolated from each other.
    %{project_id: Ecto.UUID.generate()}
  end

  defp user(email) do
    %User{id: Ecto.UUID.generate(), email: email}
  end

  # Track a user from a separate, supervised-by-the-test process so its presence
  # stays alive for the duration of the test and is cleaned up automatically.
  defp track_in_process(project_id, user) do
    test_pid = self()

    pid =
      spawn_link(fn ->
        Presence.track_user(self(), project_id, user)
        send(test_pid, :tracked)

        receive do
          :stop -> :ok
        end
      end)

    assert_receive :tracked
    wait_for_presence(project_id, user.id)
    pid
  end

  # Presence propagates asynchronously; poll briefly until the user shows up.
  defp wait_for_presence(project_id, user_id, attempts \\ 50) do
    present? =
      project_id
      |> Presence.topic()
      |> Presence.list()
      |> Map.has_key?(user_id)

    cond do
      present? ->
        :ok

      attempts == 0 ->
        flunk("presence for #{user_id} never propagated")

      true ->
        Process.sleep(20)
        wait_for_presence(project_id, user_id, attempts - 1)
    end
  end

  test "topic/1 stringifies binary and struct ids" do
    assert Presence.topic("abc") == "editor:abc"
    assert Presence.topic(%{id: "abc"}) == "editor:abc"
    assert Presence.topic(123) == "editor:123"
  end

  test "list_collaborators returns derived name, initials and color", %{project_id: project_id} do
    ada = user("ada.lovelace@typster.app")
    track_in_process(project_id, ada)

    assert [%{user_id: user_id, name: "Ada.lovelace", initials: "AL", color: color}] =
             Presence.list_collaborators(project_id)

    assert user_id == ada.id
    assert color =~ ~r/^#[0-9a-f]{6}$/
  end

  test "single local-part yields a single initial", %{project_id: project_id} do
    grace = user("grace@typster.app")
    track_in_process(project_id, grace)

    assert [%{name: "Grace", initials: "G"}] = Presence.list_collaborators(project_id)
  end

  test "list_collaborators sorts by name and excludes a user", %{project_id: project_id} do
    ada = user("ada@typster.app")
    bob = user("bob@typster.app")
    track_in_process(project_id, ada)
    track_in_process(project_id, bob)

    names = project_id |> Presence.list_collaborators() |> Enum.map(& &1.name)
    assert names == ["Ada", "Bob"]

    excluded = Presence.list_collaborators(project_id, ada.id)
    assert Enum.map(excluded, & &1.user_id) == [bob.id]
  end

  test "color is stable for the same user id across calls", %{project_id: project_id} do
    ada = user("ada@typster.app")
    track_in_process(project_id, ada)

    [%{color: first}] = Presence.list_collaborators(project_id)
    [%{color: second}] = Presence.list_collaborators(project_id)
    assert first == second
  end
end
