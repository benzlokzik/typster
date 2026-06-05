defmodule Typster.AnalyticsProTest do
  @moduledoc """
  Proves the Pro analytics feature does **real work**: `record/2` writes rows and
  `summary/2` aggregates them. `:pro`-tagged — it needs `Typster.Pro.Analytics`
  compiled in and the `pro_share_opens` table migrated (both only present in the
  Pro edition), so the open-core suite excludes it.
  """
  use Typster.DataCase, async: true

  @moduletag :pro

  @empty %{total: 0, last_7d: 0, last_at: nil, daily: [0, 0, 0, 0, 0, 0, 0]}

  test "records opens and aggregates real per-link stats" do
    token = "tok-#{System.unique_integer([:positive])}"
    other = "tok-#{System.unique_integer([:positive])}"

    # Nothing yet.
    assert Typster.Analytics.summary(token) == @empty

    # Real INSERTs: three opens for this link, one for another.
    for _ <- 1..3, do: Typster.Analytics.record(token)
    Typster.Analytics.record(other)

    summary = Typster.Analytics.summary(token)
    assert summary.total == 3
    assert summary.last_7d == 3
    assert summary.last_at != nil
    assert length(summary.daily) == 7
    # All three landed today → last bucket of the 7-day series.
    assert List.last(summary.daily) == 3

    # Aggregation is scoped per token.
    assert Typster.Analytics.summary(other).total == 1
  end

  test "the host dispatches to the real Pro implementation" do
    assert Typster.Analytics.impl() == Typster.Pro.Analytics
  end
end
