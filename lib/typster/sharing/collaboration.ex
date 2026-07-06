defmodule Typster.Sharing.Collaboration do
  @moduledoc """
  Dispatch point for the open-collaboration policy ("anyone with the link
  becomes an editor") — **not** the policy itself. Auto-joining visitors as
  collaborators is a paid capability, so the actual rule lives in the closed
  `Typster.Pro.Collaboration`. This module only routes to it.

  The open-core build carries **none** of that logic: with the Pro code absent
  it falls back to `Typster.Sharing.Collaboration.Free`, which denies every
  join. A community deployment therefore cannot auto-join a visitor at all —
  there is no host-side flag to flip, because the rule doesn't exist in the
  host. No compile-time reference to `Typster.Pro.*` (mirrors `Typster.Embed`).
  """

  alias Typster.Accounts.Scope
  alias Typster.Sharing.ShareLink

  @doc """
  True when `link` may hand a collaborator seat to a visitor, per the active
  implementation (`Typster.Pro.Collaboration` when compiled in, otherwise the
  always-deny `Typster.Sharing.Collaboration.Free`). `owner_scope` is the
  **sharer's** scope — their plan pays for the seats.
  """
  @spec open_edit?(Scope.t() | nil, ShareLink.t()) :: boolean()
  def open_edit?(owner_scope, %ShareLink{} = link), do: impl().open_edit?(owner_scope, link)

  # Runtime dispatch only — never a compile-time mention of Typster.Pro.*.
  # The `cond` shape (rather than `if`) is deliberate for the same reason as
  # `Typster.Embed.impl/0`: the opaque first branch keeps the compiler from
  # flagging `Typster.Pro.Collaboration` as undefined in the open-core build.
  # An explicit `:collaboration_impl` override lets tests inject a fake impl.
  @doc false
  @spec impl() :: module()
  def impl do
    cond do
      mod = Application.get_env(:typster, :collaboration_impl) -> mod
      Code.ensure_loaded?(Typster.Pro.Collaboration) -> Typster.Pro.Collaboration
      true -> Typster.Sharing.Collaboration.Free
    end
  end
end
