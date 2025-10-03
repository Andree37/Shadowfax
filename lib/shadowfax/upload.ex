defmodule Shadowfax.Upload do
  @moduledoc """
  Context for handling file uploads to S3 using STS temporary credentials.

  This module ONLY supports STS AssumeRole for credential management.
  All S3 operations use temporary, auto-rotating credentials for security.
  """

  require Logger

  @max_file_size 50 * 1024 * 1024
  @allowed_image_types ["image/png", "image/jpeg", "image/jpg", "image/gif", "image/webp"]
  @allowed_file_types [
    "application/pdf",
    "text/plain",
    "application/msword",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "application/vnd.ms-excel",
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  ]

  @doc """
  Uploads a file to S3 and returns the attachment metadata.
  """
  def upload_file(file_binary, filename, content_type) do
    with :ok <- validate_file_size(byte_size(file_binary)),
         :ok <- validate_content_type(content_type),
         {:ok, s3_key} <- generate_s3_key(filename),
         {:ok, _response} <- upload_to_s3(s3_key, file_binary, content_type) do
      {:ok, build_attachment_metadata(s3_key, filename, content_type, byte_size(file_binary))}
    end
  end

  @doc """
  Deletes a file from S3.
  """
  def delete_file(s3_key) do
    bucket_name = get_bucket_name()
    request_opts = build_request_opts()

    ExAws.S3.delete_object(bucket_name, s3_key)
    |> ExAws.request(request_opts)
  end

  @doc """
  Generates a presigned URL for uploading directly from the client.
  Uses STS temporary credentials for signing the URL.
  """
  def generate_presigned_upload_url(filename, content_type) do
    with :ok <- validate_content_type(content_type),
         {:ok, s3_key} <- generate_s3_key(filename),
         {:ok, credentials} <- Shadowfax.AWS.STSCredentials.get_credentials() do
      bucket_name = get_bucket_name()
      region = get_region()

      # Build config with STS credentials
      config = %{
        access_key_id: credentials.access_key_id,
        secret_access_key: credentials.secret_access_key,
        security_token: credentials.session_token,
        region: region
      }

      presigned_url =
        ExAws.S3.presigned_url(
          config,
          :put,
          bucket_name,
          s3_key,
          expires_in: 3600,
          query_params: [],
          virtual_host: false
        )

      case presigned_url do
        {:ok, url} ->
          {:ok,
           %{
             upload_url: url,
             s3_key: s3_key,
             filename: filename,
             content_type: content_type
           }}

        error ->
          error
      end
    end
  end

  @doc """
  Builds attachment metadata after a successful upload.
  """
  def build_attachment_metadata(s3_key, filename, content_type, size) do
    %{
      id: Ecto.UUID.generate(),
      filename: filename,
      url: get_public_url(s3_key),
      content_type: content_type,
      size: size,
      s3_key: s3_key
    }
  end

  @doc """
  Validates that a file size is within limits.
  """
  def validate_file_size(size) when size > @max_file_size do
    {:error, "File size exceeds maximum allowed size of #{@max_file_size} bytes"}
  end

  def validate_file_size(_size), do: :ok

  @doc """
  Validates that a content type is allowed.
  """
  def validate_content_type(content_type) do
    if content_type in (@allowed_image_types ++ @allowed_file_types) do
      :ok
    else
      {:error, "Content type #{content_type} is not allowed"}
    end
  end

  @doc """
  Returns whether a content type is an image.
  """
  def is_image?(content_type) do
    content_type in @allowed_image_types
  end

  # Private functions

  defp generate_s3_key(filename) do
    # Generate a unique key using UUID and preserve file extension
    extension = Path.extname(filename)
    uuid = Ecto.UUID.generate()
    timestamp = DateTime.utc_now() |> DateTime.to_unix()

    # Organize by date for easier management
    date_prefix = Date.utc_today() |> Date.to_string() |> String.replace("-", "/")

    s3_key = "uploads/#{date_prefix}/#{timestamp}-#{uuid}#{extension}"
    {:ok, s3_key}
  end

  defp upload_to_s3(s3_key, file_binary, content_type) do
    bucket_name = get_bucket_name()

    request_opts = build_request_opts()

    ExAws.S3.put_object(bucket_name, s3_key, file_binary,
      content_type: content_type,
      acl: :public_read
    )
    |> ExAws.request(request_opts)
  end

  defp build_request_opts do
    # STS is always enabled - this is enforced at config level
    case Shadowfax.AWS.STSCredentials.get_credentials() do
      {:ok, credentials} ->
        [
          access_key_id: credentials.access_key_id,
          secret_access_key: credentials.secret_access_key,
          security_token: credentials.session_token
        ]

      {:error, reason} ->
        Logger.error("Failed to get STS credentials: #{inspect(reason)}")

        raise """
        STS credentials not available. Ensure:
        1. AWS_ROLE_ARN is set
        2. Base credentials have sts:AssumeRole permission
        3. The STS GenServer started successfully

        See IMAGE_UPLOAD.md for setup instructions.
        """
    end
  end

  defp get_public_url(s3_key) do
    bucket_name = get_bucket_name()
    region = get_region()

    "https://#{bucket_name}.s3.#{region}.amazonaws.com/#{s3_key}"
  end

  defp get_bucket_name do
    Application.get_env(:ex_aws, :s3)[:bucket] ||
      raise "S3 bucket name not configured"
  end

  defp get_region do
    Application.get_env(:ex_aws, :region, "us-east-1")
  end
end
