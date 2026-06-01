defmodule Typster.Projects.Project do
  @moduledoc "Schema for user-owned projects"
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "projects" do
    field :name, :string
    belongs_to :user, Typster.Accounts.User
    has_many :files, Typster.Projects.File
    has_many :assets, Typster.Assets.Asset
    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(project, attrs) do
    project
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> validate_required([:user_id])
    |> assoc_constraint(:user)
  end
end
