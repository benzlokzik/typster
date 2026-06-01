defmodule Typster.Features.Impl do
  @moduledoc """
  The behaviour every entitlements implementation follows.

  `Typster.Features.Free` (open core) implements this with `@behaviour`. The
  private `Typster.Pro.Features` implements it **by convention** — it cannot
  declare `@behaviour Typster.Features.Impl`, because `:typster_pro` is a
  dependency of `:typster` and compiles first, so this module is not visible to
  it at compile time. The contract therefore lives here as documentation and a
  Dialyzer surface for the host side.
  """

  alias Typster.Accounts.Scope

  @callback can?(Scope.t() | nil, Typster.Features.feature()) :: boolean()
end
