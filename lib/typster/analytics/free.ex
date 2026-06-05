defmodule Typster.Analytics.Free do
  @moduledoc """
  Open-core analytics: records nothing and reports zeros.

  The community build dispatches here when `Typster.Pro.Analytics` is not
  compiled in. There is no analytics table and no query logic in open core — the
  real implementation is Pro-only — so recording is a no-op and every summary is
  empty.
  """

  @doc "No-op: open core stores no analytics."
  def record(_repo, _token, _opts \\ []), do: {0, nil}

  @doc "Empty summary: total 0, no opens, a flat 7-day series."
  def summary(_repo, _token),
    do: %{total: 0, last_7d: 0, last_at: nil, daily: List.duplicate(0, 7)}
end
