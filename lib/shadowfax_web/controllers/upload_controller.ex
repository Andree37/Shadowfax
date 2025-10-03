defmodule ShadowfaxWeb.UploadController do
  use ShadowfaxWeb, :controller

  alias Shadowfax.Upload

  plug ShadowfaxWeb.Plugs.Authenticate

  @doc """
  Handles direct file upload to the server, which then uploads to S3.

  Expects multipart/form-data with a 'file' field.
  """
  def create(conn, %{"file" => file}) do
    with {:ok, file_binary} <- File.read(file.path),
         {:ok, attachment} <- Upload.upload_file(file_binary, file.filename, file.content_type) do
      conn
      |> put_status(:created)
      |> json(%{
        success: true,
        attachment: attachment
      })
    else
      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          success: false,
          error: reason
        })
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{
      success: false,
      error: "No file provided"
    })
  end

  @doc """
  Generates a presigned URL for direct client-to-S3 upload.

  This is more efficient as the file doesn't go through your server.
  """
  def presigned_url(conn, %{"filename" => filename, "content_type" => content_type}) do
    case Upload.generate_presigned_upload_url(filename, content_type) do
      {:ok, presigned_data} ->
        conn
        |> put_status(:ok)
        |> json(%{
          success: true,
          data: presigned_data
        })

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          success: false,
          error: reason
        })
    end
  end

  def presigned_url(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{
      success: false,
      error: "Missing filename or content_type"
    })
  end
end
