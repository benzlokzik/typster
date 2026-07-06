defmodule Typster.Assets do
  @moduledoc """
  The Assets context.
  """

  import Ecto.Query, warn: false
  alias Typster.Accounts.Scope
  alias Typster.Assets.Asset
  alias Typster.Repo
  alias Typster.Sharing.Collaborator

  def get_asset!(%Scope{user: user}, id) do
    from(a in Asset,
      join: p in assoc(a, :project),
      left_join: c in Collaborator,
      on: c.project_id == p.id and c.user_id == ^user.id and c.status == :accepted,
      where: a.id == ^id and (p.user_id == ^user.id or not is_nil(c.id))
    )
    |> Repo.one!()
  end

  def get_asset(%Scope{user: user}, id) do
    from(a in Asset,
      join: p in assoc(a, :project),
      left_join: c in Collaborator,
      on: c.project_id == p.id and c.user_id == ^user.id and c.status == :accepted,
      where: a.id == ^id and (p.user_id == ^user.id or not is_nil(c.id))
    )
    |> Repo.one()
  end

  def upload_asset(%Scope{} = scope, project_id, object_key, attrs) do
    _project = Typster.Projects.get_editable_project!(scope, project_id)

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
    _project = Typster.Projects.get_editable_project!(scope, project_id)

    from(a in Asset,
      where: a.project_id == ^project_id,
      order_by: [desc: a.inserted_at]
    )
    |> Repo.all()
  end

  def change_asset(%Asset{} = asset, attrs \\ %{}) do
    Asset.changeset(asset, attrs)
  end

  @doc """
  Copies every asset of `source_project_id` into `target_project_id`,
  duplicating each S3 object under a fresh key (forks must not share objects —
  deleting the original would break the copy).

  No scope: authorization is the caller's job (`Typster.Projects.fork_project/3`
  runs this inside its transaction). Returns `:ok`, or `{:error, reason}` on
  the first failed S3 copy so the caller can roll the fork back.
  """
  def copy_project_assets(source_project_id, target_project_id) do
    bucket = Application.get_env(:typster, :s3_bucket, "typster-assets")

    from(a in Asset, where: a.project_id == ^source_project_id)
    |> Repo.all()
    |> Enum.reduce_while(:ok, fn asset, :ok ->
      new_key = object_key(target_project_id, asset.filename)

      case ExAws.S3.put_object_copy(bucket, new_key, bucket, asset.object_key)
           |> ExAws.request() do
        {:ok, _} ->
          Repo.insert!(%Asset{
            project_id: target_project_id,
            object_key: new_key,
            content_type: asset.content_type,
            size: asset.size,
            filename: asset.filename,
            inserted_at: DateTime.utc_now(:second)
          })

          {:cont, :ok}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
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

    put = fn ->
      ExAws.S3.put_object(bucket, object_key, body, content_type: content_type)
      |> ExAws.request()
    end

    case put.() do
      # Bucket missing (e.g. a fresh MinIO): create it once, then retry.
      {:error, {:http_error, 404, _}} ->
        region = Application.get_env(:ex_aws, :region, "us-east-1")
        _ = ExAws.S3.put_bucket(bucket, region) |> ExAws.request()
        put.()

      result ->
        result
    end
  end
end
