defmodule Typster.Assets do
  @moduledoc """
  The Assets context.
  """

  import Ecto.Query, warn: false
  alias Typster.Accounts.Scope
  alias Typster.Repo
  alias Typster.Assets.Asset

  def get_asset!(%Scope{user: user}, id) do
    from(a in Asset,
      join: p in assoc(a, :project),
      where: a.id == ^id and p.user_id == ^user.id
    )
    |> Repo.one!()
  end

  def get_asset(%Scope{user: user}, id) do
    from(a in Asset,
      join: p in assoc(a, :project),
      where: a.id == ^id and p.user_id == ^user.id
    )
    |> Repo.one()
  end

  def upload_asset(%Scope{} = scope, project_id, object_key, attrs) do
    _project = Typster.Projects.get_project!(scope, project_id)

    %Asset{project_id: project_id, inserted_at: DateTime.utc_now(:second)}
    |> Asset.changeset(
      Map.merge(attrs, %{
        object_key: object_key
      })
    )
    |> Repo.insert()
  end

  def upload_entry(%Scope{} = scope, project_id, %{path: path} = entry) do
    filename = Map.fetch!(entry, :client_name)
    content_type = Map.get(entry, :client_type) || MIME.from_path(filename)
    object_key = object_key(project_id, filename)
    safe_path = safe_upload_path!(path)
    size = File.stat!(safe_path).size
    body = File.read!(safe_path)

    with {:ok, _response} <- put_object(object_key, body, content_type) do
      upload_asset(scope, project_id, object_key, %{
        filename: filename,
        content_type: content_type,
        size: size
      })
    end
  end

  def get_asset_url(%Asset{} = asset) do
    config = ExAws.Config.new(:s3)
    bucket = Application.get_env(:typster, :s3_bucket, "typster-assets")

    ExAws.S3.presigned_url(
      config,
      :get,
      bucket,
      asset.object_key,
      expires_in: 3600
    )
  end

  def delete_asset(%Scope{} = scope, %Asset{} = asset) do
    asset = get_asset!(scope, asset.id)
    bucket = Application.get_env(:typster, :s3_bucket, "typster-assets")

    ExAws.S3.delete_object(bucket, asset.object_key)
    |> ExAws.request()

    Repo.delete(asset)
  end

  def list_assets(%Scope{} = scope, project_id) do
    _project = Typster.Projects.get_project!(scope, project_id)

    from(a in Asset,
      where: a.project_id == ^project_id,
      order_by: [desc: a.inserted_at]
    )
    |> Repo.all()
  end

  def change_asset(%Asset{} = asset, attrs \\ %{}) do
    Asset.changeset(asset, attrs)
  end

  def reference_path(%Asset{} = asset), do: "assets/#{asset.filename}"

  defp safe_upload_path!(path) do
    expanded = Path.expand(path)
    tmp_dir = Path.expand(System.tmp_dir!())

    unless String.starts_with?(expanded, tmp_dir <> "/") do
      raise ArgumentError, "upload path is outside the system temp directory"
    end

    expanded
  end

  defp object_key(project_id, filename) do
    safe_name =
      filename
      |> Path.basename()
      |> String.replace(~r/[^A-Za-z0-9._-]/, "-")

    "projects/#{project_id}/assets/#{System.unique_integer([:positive])}-#{safe_name}"
  end

  defp put_object(object_key, body, content_type) do
    bucket = Application.get_env(:typster, :s3_bucket, "typster-assets")

    ExAws.S3.put_object(bucket, object_key, body, content_type: content_type)
    |> ExAws.request()
  end
end
