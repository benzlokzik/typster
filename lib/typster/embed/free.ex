defmodule Typster.Embed.Free do
  @moduledoc """
  Open-core embed policy: everything locked.

  The community build dispatches here when `Typster.Pro.Embed` is not compiled
  in. The editable sandbox, the unbranded footer, and the smart CTA are all paid
  capabilities whose logic lives only in `Typster.Pro.Embed`, so without it every
  embed is read-only, branded, and shows the fixed "Open in Typster" CTA. This is
  not a gate over hidden logic — there simply is no Pro logic here to unlock.
  """

  @doc "The locked policy: read-only, branded, fixed `:open` CTA."
  @spec policy(any(), map()) :: Typster.Embed.t()
  def policy(_owner, _params), do: %{editable: false, unbranded: false, cta: %{mode: :open}}
end
