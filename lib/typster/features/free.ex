defmodule Typster.Features.Free do
  @moduledoc """
  Open-core entitlements: every gateable Pro feature is denied.

  This is the implementation the community build always uses. It exists so the
  host has a concrete, dependency-free fallback when `Typster.Pro.Features` is
  not compiled in. A user whose account is nominally `:pro` still gets `false`
  here when no Pro code is present — correct, because the feature cannot run.
  """

  @behaviour Typster.Features.Impl

  @impl true
  def can?(_scope, _feature), do: false
end
