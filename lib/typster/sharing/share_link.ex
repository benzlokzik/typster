defmodule Typster.Sharing.ShareLink do
  @moduledoc """
  A public share link for a project.

  One link exists per project. The `token` and `project_id` are set
  programmatically (never cast from user params); only `scope`,
  `allow_download`, `allow_fork`, and `open_edit` are user-editable.

  `allow_fork` lets any signed-in visitor clone the project under their own
  account. `open_edit` auto-joins visitors as accepted `:editor` collaborators
  — a Pro capability, additionally gated by the **owner's** entitlement at
  join time (see `Typster.Sharing.join_via_link/2`). Both default to off.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{
          id: binary() | nil,
          token: String.t() | nil,
          scope: :read | :output | :full,
          allow_download: boolean(),
          allow_fork: boolean(),
          open_edit: boolean(),
          project_id: binary() | nil,
          project: Typster.Projects.Project.t() | Ecto.Association.NotLoaded.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "share_links" do
    field :token, :string
    field :scope, Ecto.Enum, values: [:read, :output, :full], default: :read
    field :allow_download, :boolean, default: true
    field :allow_fork, :boolean, default: false
    field :open_edit, :boolean, default: false
    belongs_to :project, Typster.Projects.Project
    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for user-editable link settings.

  `token` and `project_id` are intentionally excluded from `cast/3` and must be
  set programmatically by the context.
  """
  def changeset(share_link, attrs) do
    share_link
    |> cast(attrs, [:scope, :allow_download, :allow_fork, :open_edit])
    |> validate_required([:scope, :allow_download, :allow_fork, :open_edit])
  end

  @doc """
  Returns a fresh url-safe token formatted as three dashed 4-character groups,
  e.g. `"k3f9-7m2x-w8q1"`.
  """
  def gen_token, do: do_gen_token()

  defp do_gen_token do
    :crypto.strong_rand_bytes(9)
    |> Base.url_encode64(padding: false)
    |> binary_part(0, 12)
    |> String.downcase()
    |> String.replace(["-", "_"], "x")
    |> group_in_fours()
  end

  defp group_in_fours(<<a::binary-size(4), b::binary-size(4), c::binary-size(4)>>) do
    "#{a}-#{b}-#{c}"
  end
end
