defmodule ShadowfaxWeb.AuthHelpers do
  @moduledoc """
  Helper functions for authentication in tests.
  """

  alias Shadowfax.Accounts
  alias Shadowfax.Accounts.AuthToken

  @doc """
  Creates a valid access token for a user in tests.
  Stores the token in the database so it can be verified.
  """
  def create_test_token(user) do
    token_salt = Application.get_env(:shadowfax, :token_salt, "user_auth_token")
    token_version = Application.get_env(:shadowfax, :token_version, 1)

    # Generate token using Phoenix.Token
    token_string =
      Phoenix.Token.sign(
        ShadowfaxWeb.Endpoint,
        token_salt,
        %{user_id: user.id, type: "access", version: token_version}
      )

    # Hash and store in database
    token_hash = AuthToken.hash_token(token_string)

    {:ok, _auth_token} =
      Accounts.create_auth_token(%{
        user_id: user.id,
        token_hash: token_hash,
        token_type: "access",
        token_version: token_version,
        expires_at:
          DateTime.utc_now() |> DateTime.add(900, :second) |> DateTime.truncate(:second),
        device_info: %{user_agent: "test"},
        ip_address: "127.0.0.1"
      })

    token_string
  end

  @doc """
  Creates a refresh token for a user in tests.
  """
  def create_test_refresh_token(user) do
    token_salt = Application.get_env(:shadowfax, :token_salt, "user_auth_token")
    token_version = Application.get_env(:shadowfax, :token_version, 1)

    token_string =
      Phoenix.Token.sign(
        ShadowfaxWeb.Endpoint,
        token_salt,
        %{user_id: user.id, type: "refresh", version: token_version}
      )

    token_hash = AuthToken.hash_token(token_string)

    {:ok, _auth_token} =
      Accounts.create_auth_token(%{
        user_id: user.id,
        token_hash: token_hash,
        token_type: "refresh",
        token_version: token_version,
        expires_at:
          DateTime.utc_now() |> DateTime.add(2_592_000, :second) |> DateTime.truncate(:second),
        device_info: %{user_agent: "test"},
        ip_address: "127.0.0.1"
      })

    token_string
  end
end
