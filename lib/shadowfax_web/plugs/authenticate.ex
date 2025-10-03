defmodule ShadowfaxWeb.Plugs.Authenticate do
  @moduledoc """
  Plug to authenticate requests using Bearer token authentication.
  Verifies the token and loads the current user into assigns.
  Now includes blacklist checking and database-backed token validation.
  """
  import Plug.Conn
  import Phoenix.Controller

  alias Shadowfax.Accounts
  alias ShadowfaxWeb.Errors

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        verify_and_load_user(conn, token)

      _ ->
        unauthorized(conn, Errors.missing_authorization())
    end
  end

  defp verify_and_load_user(conn, token) do
    case Accounts.verify_token(token, "access") do
      {:ok, user, _auth_token} ->
        conn
        |> assign(:current_user, user)
        |> assign(:current_user_id, user.id)

      {:error, :token_blacklisted} ->
        unauthorized(conn, Errors.token_revoked())

      {:error, :token_expired} ->
        unauthorized(conn, Errors.token_expired())

      {:error, :token_not_found} ->
        unauthorized(conn, Errors.invalid_token())

      {:error, :invalid_token_type} ->
        unauthorized(conn, Errors.invalid_token_type())

      {:error, _reason} ->
        unauthorized(conn, Errors.invalid_token())
    end
  end

  defp unauthorized(conn, message) do
    conn
    |> put_status(:unauthorized)
    |> json(Errors.error_response(message))
    |> halt()
  end
end
