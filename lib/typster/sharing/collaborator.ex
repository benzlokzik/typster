defmodule Typster.Sharing.Collaborator do
  @moduledoc """
  A collaborator invited to a project by email.

  `project_id` and `status` are set programmatically; only `email` and `role`
  are user-editable. `user_id` is linked when the invitee has an account.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{
          id: binary() | nil,
          email: String.t() | nil,
          role: :owner | :editor | :viewer,
          status: :pending | :accepted,
          project_id: binary() | nil,
          user_id: binary() | nil,
          project: Typster.Projects.Project.t() | Ecto.Association.NotLoaded.t() | nil,
          user: Typster.Accounts.User.t() | Ecto.Association.NotLoaded.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "collaborators" do
    field :email, :string
    field :role, Ecto.Enum, values: [:owner, :editor, :viewer], default: :viewer
    field :status, Ecto.Enum, values: [:pending, :accepted], default: :pending
    belongs_to :project, Typster.Projects.Project
    belongs_to :user, Typster.Accounts.User
    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for inviting or editing a collaborator.

  `project_id`, `status`, and `user_id` are set programmatically and excluded
  from `cast/3`.
  """
  def changeset(collaborator, attrs) do
    collaborator
    |> cast(attrs, [:email, :role])
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
      message: "must have the @ sign and no spaces"
    )
    |> validate_length(:email, max: 160)
    |> unique_constraint([:project_id, :email],
      name: :collaborators_project_id_email_index,
      message: "is already a collaborator on this project"
    )
  end

  @doc """
  Changeset that links a pending invite to a user account and marks it accepted.

  `user_id` and `status` are set programmatically here (never via user params),
  which is why they are excluded from `changeset/2`'s `cast/3`.
  """
  def accept_changeset(collaborator, user_id) do
    change(collaborator, user_id: user_id, status: :accepted)
  end
end
