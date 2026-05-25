defmodule Typster.Templates.Template do
  @moduledoc "Schema for a user's reusable new-file templates."
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "templates" do
    field :name, :string
    field :content, :string
    belongs_to :user, Typster.Accounts.User
    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(template, attrs) do
    template
    |> cast(attrs, [:name, :content])
    |> validate_required([:name])
    |> validate_length(:name, max: 255)
  end
end
