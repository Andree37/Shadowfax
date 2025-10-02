defmodule ShadowfaxWeb.Plugs.Authenticate do
  @moduledoc """
  Plug to authenticate requests using Bearer token authentication.
  Verifies the token and loads the current user into assigns.
  """
  import Plug.Conn
  import Phoenix.Controller

  alias Shadowfax.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        verify_and_load_user(conn, token)

      _ ->
        unauthorized(conn)
    end
  end

  defp verify_and_load_user(conn, token) do
    case Phoenix.Token.verify(ShadowfaxWeb.Endpoint, "user auth", token, max_age: 1_209_600) do
      {:ok, user_id} ->
        try do
          user = Accounts.get_user!(user_id)
          assign(conn, :current_user, user)
        rescue
          Ecto.NoResultsError -> unauthorized(conn)
        end

      {:error, _reason} ->
        unauthorized(conn)
    end
  end

  defp unauthorized(conn) do
    conn
    |> put_status(:unauthorized)
    |> json(%{
      success: false,
      error: "Authentication required"
    })
    |> halt()
  end
end
