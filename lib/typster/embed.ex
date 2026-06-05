defmodule Typster.Embed do
  @moduledoc """
  Dispatch point for the public `/embed/:token` policy — **not** the policy
  itself. Whether an embed is an editable sandbox, unbranded, and which footer
  CTA it shows are paid capabilities, so the actual logic lives in the closed
  `Typster.Pro.Embed`. This module only routes to it.

  The open-core build carries **none** of that logic: with the Pro code absent it
  falls back to `Typster.Embed.Free`, which locks every embed down (read-only,
  branded, fixed CTA). A community deployment therefore cannot produce a Pro
  embed at all — there is no host-side flag to flip, because the rules don't
  exist in the host. No compile-time reference to `Typster.Pro.*`
  (mirrors `Typster.Features`).
  """

  alias Typster.Accounts.Scope

  @type cta :: %{mode: :open | :signup | :fork | :none}
  @type t :: %{editable: boolean(), unbranded: boolean(), cta: cta()}

  @doc """
  The embed policy for the link `owner_scope` and the embed's query `params`,
  resolved by the active implementation (`Typster.Pro.Embed` when compiled in,
  otherwise the locked-down `Typster.Embed.Free`).
  """
  @spec policy(Scope.t() | nil, map()) :: t()
  def policy(owner_scope, params) when is_map(params), do: impl().policy(owner_scope, params)

  # Runtime dispatch only — never a compile-time mention of Typster.Pro.*.
  #
  # The `cond` (rather than a plain `if`) is deliberate: its first branch yields
  # an opaque value from `Application.get_env/2`, which widens the inferred return
  # type to `module()`. A bare `if … Typster.Pro.Embed … Typster.Embed.Free` would
  # let the compiler infer the literal target and flag `Typster.Pro.Embed.policy/2`
  # as undefined in the open-core build (no submodule). An explicit `:embed_impl`
  # override also lets tests inject a fake Pro impl. Mirrors `Typster.Features.impl/0`.
  @doc false
  @spec impl() :: module()
  def impl do
    cond do
      mod = Application.get_env(:typster, :embed_impl) -> mod
      Code.ensure_loaded?(Typster.Pro.Embed) -> Typster.Pro.Embed
      true -> Typster.Embed.Free
    end
  end
end
