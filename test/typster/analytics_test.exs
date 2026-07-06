defmodule Typster.AnalyticsTest do
  use Typster.DataCase, async: false

  alias Typster.Analytics

  defmodule ExplodingImpl do
    def record(_repo, _token, _opts), do: raise(RuntimeError, "table missing")
    def summary(_repo, _token), do: raise(RuntimeError, "table missing")
  end

  # A failing analytics impl (e.g. a Pro build whose pro_share_opens migration
  # hasn't run) must degrade gracefully — a public embed/share open must never
  # 500 because of a stats INSERT, and the owner's Share modal must still open.
  describe "best-effort dispatch" do
    setup do
      Application.put_env(:typster, :analytics_impl, ExplodingImpl)
      on_exit(fn -> Application.delete_env(:typster, :analytics_impl) end)
      :ok
    end

    test "record/2 swallows impl crashes" do
      assert Analytics.record("some-token") == :error
    end

    test "summary/1 degrades to zeros when the impl crashes" do
      assert %{total: 0, last_7d: 0, last_at: nil, daily: daily} =
               Analytics.summary("some-token")

      assert Enum.all?(daily, &(&1 == 0))
    end
  end
end
