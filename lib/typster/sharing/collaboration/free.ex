defmodule Typster.Sharing.Collaboration.Free do
  @moduledoc """
  Open-core open-collaboration policy: every auto-join is denied.

  The community fallback for `Typster.Sharing.Collaboration` when the Pro code
  is not compiled in. A link owner whose account is nominally `:pro` still gets
  `false` here — correct, because the capability cannot run without the Pro
  implementation (mirrors `Typster.Features.Free`).
  """

  def open_edit?(_owner_scope, _link), do: false
end
