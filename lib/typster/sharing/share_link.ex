defmodule Typster.Sharing.ShareLink do
  @moduledoc """
  A public share link for a project.

  One link exists per project. The `token` and `project_id` are set
  programmatically (never cast from user params); only `scope` and
  `allow_download` are user-editable.
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
          project_id: binary() | nil,
          project: Typster.Projects.Project.t() | Ecto.Association.NotLoaded.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "share_links" do
    field :token, :string
    field :scope, Ecto.Enum, values: [:read, :output, :full], default: :read
    field :allow_download, :boolean, default: true
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
    |> cast(attrs, [:scope, :allow_download])
    |> validate_required([:scope, :allow_download])
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
