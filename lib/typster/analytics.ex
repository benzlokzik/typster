defmodule Typster.Analytics do
  @moduledoc """
  Share-link analytics dispatch — **not** the implementation.

  Recording each open of a shared link and aggregating the opens is a paid
  capability whose real behaviour (its own `pro_share_opens` table, the INSERT,
  the aggregate queries) lives in the closed `Typster.Pro.Analytics`. This module
  only routes to it, injecting the host `Repo` (the Pro app holds no Repo and
  compiles before the host).

  Without the Pro code it falls back to `Typster.Analytics.Free`: a community
  build records nothing and reports zeros — it has no analytics table and no
  query logic at all. No compile-time reference to `Typster.Pro.*`.
  """

  @type summary :: %{
          total: non_neg_integer(),
          last_7d: non_neg_integer(),
          last_at: DateTime.t() | nil,
          daily: [non_neg_integer()]
        }

  @doc "Records one open of the share link `token`. Best-effort; no-op on community."
  @spec record(String.t(), keyword()) :: term()
  def record(token, opts \\ []) when is_binary(token),
    do: impl().record(Typster.Repo, token, opts)

  @doc "Aggregated open stats for `token` (all zeros on the community build)."
  @spec summary(String.t()) :: summary()
  def summary(token) when is_binary(token), do: impl().summary(Typster.Repo, token)

  # Runtime dispatch only — mirrors Typster.Features / Typster.Embed.
  @doc false
  @spec impl() :: module()
  def impl do
    cond do
      mod = Application.get_env(:typster, :analytics_impl) -> mod
      Code.ensure_loaded?(Typster.Pro.Analytics) -> Typster.Pro.Analytics
      true -> Typster.Analytics.Free
    end
  end

  @doc """
  The Pro HEEx component module for the analytics panel, or `nil` on the
  open-core build. The Pro repo owns the panel's markup; the host only invokes
  it and passes in host-resolved data + labels. `nil` whenever the panel isn't
  available — and it's only ever shown to entitled owners anyway.
  """
  @spec components() :: module() | nil
  def components do
    if Code.ensure_loaded?(Typster.Pro.Analytics.Components),
      do: Typster.Pro.Analytics.Components
  end
end
