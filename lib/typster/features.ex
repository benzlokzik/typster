defmodule Typster.Features do
  @moduledoc """
  Entitlements layer for Typster's open-core model.

  Gate every paid capability through `can?/2`. Never scatter
  `if scope.plan == :pro` checks across the codebase — route them through here
  so the free/Pro boundary lives in exactly one place.

  At runtime this dispatches to the private `Typster.Pro.Features` when the Pro
  submodule is compiled in, and otherwise to `Typster.Features.Free`, which
  denies every Pro feature. The dispatch uses `Code.ensure_loaded?/1`, so the
  open-core build contains **no compile-time reference** to `Typster.Pro.*` and
  stays green under `mix compile --warning-as-errors`.

  The catalog is intentionally tiny — only genuinely paid capabilities. The
  editor and all of its features, live collaboration, and basic sharing are
  free and are deliberately *not* listed here.
  """

  alias Typster.Accounts.Scope

  @typedoc "A gateable Pro capability."
  @type feature ::
          :share_write_scoped
          | :share_advanced_link
          | :share_link_analytics
          | :share_embed_sandbox
          | :share_embed_smart_cta
          | :share_embed_unbranded
          | :share_open_collaboration

  @features ~w(
    share_write_scoped
    share_advanced_link
    share_link_analytics
    share_embed_sandbox
    share_embed_smart_cta
    share_embed_unbranded
    share_open_collaboration
  )a

  @doc "The full catalog of gateable Pro features."
  @spec catalog() :: [feature()]
  def catalog, do: @features

  @doc """
  Returns true when `scope` is entitled to `feature`.

  Open-core build: always false for every Pro feature (the feature literally
  cannot run without the Pro code). Pro build: delegates to
  `Typster.Pro.Features`, which checks the scope's plan and any finer grant.

  Raises `FunctionClauseError` for an unknown feature — a deliberate strict
  boundary so typos fail loudly instead of silently granting/denying.
  """
  @spec can?(Scope.t() | nil, feature()) :: boolean()
  def can?(scope, feature) when feature in @features do
    impl().can?(scope, feature)
  end

  @doc """
  The nominal plan a scope is on (`:free` | `:pro`), straight from the account.

  This is the *billing* status used for UI ("You're on Free"), independent of
  whether the Pro code is loaded. Whether a feature can actually run always
  goes through `can?/2`.
  """
  @spec plan(Scope.t() | nil) :: :free | :pro
  def plan(%Scope{plan: plan}) when plan in [:free, :pro], do: plan
  def plan(_), do: :free

  @doc "True when the scope is nominally on the Pro plan — for upsell UI."
  @spec pro?(Scope.t() | nil) :: boolean()
  def pro?(scope), do: plan(scope) == :pro

  # Runtime dispatch only — never a compile-time reference to Typster.Pro.*.
  # An explicit `:features_impl` override lets tests inject a fake Pro impl
  # without the submodule being present.
  @doc false
  @spec impl() :: module()
  def impl do
    cond do
      mod = Application.get_env(:typster, :features_impl) -> mod
      Code.ensure_loaded?(Typster.Pro.Features) -> Typster.Pro.Features
      true -> Typster.Features.Free
    end
  end
end
