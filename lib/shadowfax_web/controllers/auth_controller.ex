defmodule ShadowfaxWeb.AuthController do
  use ShadowfaxWeb, :controller

  alias Shadowfax.Accounts
  alias Shadowfax.Accounts.User
  alias Shadowfax.Accounts.AuthToken
  alias ShadowfaxWeb.Errors

  @doc """
  Register a new user
  """
  def register(conn, %{"user" => user_params}) do
    case Accounts.create_user(user_params) do
      {:ok, user} ->
        {:ok, access_token, refresh_token} = generate_token_pair(user, conn)

        conn
        |> put_status(:created)
        |> json(%{
          success: true,
          data: %{
            user: serialize_user(user),
            access_token: access_token,
            refresh_token: refresh_token,
            token_type: "Bearer",
            expires_in: AuthToken.get_ttl("access")
          }
        })

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          success: false,
          errors: serialize_errors(changeset)
        })
    end
  end

  def register(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(Errors.error_response(Errors.invalid_request("user")))
  end

  @doc """
  Login user
  """
  def login(conn, %{"email" => email, "password" => password}) do
    case Accounts.get_user_by_email_and_password(email, password) do
      %User{} = user ->
        {:ok, access_token, refresh_token} = generate_token_pair(user, conn)

        conn
        |> json(%{
          success: true,
          data: %{
            user: serialize_user(user),
            access_token: access_token,
            refresh_token: refresh_token,
            token_type: "Bearer",
            expires_in: AuthToken.get_ttl("access")
          }
        })

      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(Errors.error_response(Errors.invalid_credentials()))
    end
  end

  def login(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(Errors.error_response(Errors.credentials_required()))
  end

  @doc """
  Logout user - revokes current token and optionally all user tokens
  """
  def logout(conn, params) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         token_hash <- AuthToken.hash_token(token),
         %AuthToken{} = auth_token <- Accounts.get_auth_token_by_hash(token_hash) do
      # Blacklist the current token
      Accounts.blacklist_token(
        token_hash,
        auth_token.user_id,
        "logout",
        auth_token.expires_at
      )

      # Delete the token from database
      Accounts.delete_auth_token(auth_token)

      # If logout_all is true, revoke all user tokens
      if params["logout_all"] do
        Accounts.revoke_all_user_tokens(auth_token.user_id, "logout_all_devices")
      end

      conn
      |> json(%{
        success: true,
        message: "Successfully logged out"
      })
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(Errors.error_response(Errors.not_authenticated()))
    end
  end

  @doc """
  Get current user info
  """
  def me(conn, _params) do
    case get_current_user(conn) do
      %User{} = user ->
        conn
        |> json(%{
          success: true,
          data: %{
            user: serialize_user(user)
          }
        })

      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(Errors.error_response(Errors.not_authenticated()))
    end
  end

  @doc """
  Verify token validity
  """
  def verify_token_endpoint(conn, _params) do
    case conn.assigns[:current_user] do
      %User{} = user ->
        conn
        |> json(%{
          success: true,
          data: %{
            user: serialize_user(user),
            valid: true
          }
        })

      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{
          success: false,
          error: Errors.invalid_or_expired_token(),
          valid: false
        })
    end
  end

  @doc """
  Refresh access token using a refresh token
  """
  def refresh(conn, %{"refresh_token" => refresh_token}) do
    case Accounts.verify_token(refresh_token, "refresh") do
      {:ok, user, _token} ->
        {:ok, access_token, new_refresh_token} = generate_token_pair(user, conn)

        conn
        |> json(%{
          success: true,
          data: %{
            access_token: access_token,
            refresh_token: new_refresh_token,
            token_type: "Bearer",
            expires_in: AuthToken.get_ttl("access")
          }
        })

      {:error, reason} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{
          success: false,
          error: Errors.invalid_refresh_token(),
          reason: reason
        })
    end
  end

  def refresh(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(Errors.error_response(Errors.refresh_token_required()))
  end

  @doc """
  List all active sessions (tokens) for the current user
  """
  def sessions(conn, _params) do
    case conn.assigns[:current_user] do
      %User{} = user ->
        tokens = Accounts.list_user_tokens(user.id)

        conn
        |> json(%{
          success: true,
          data: %{
            sessions:
              Enum.map(tokens, fn token ->
                %{
                  id: token.id,
                  token_type: token.token_type,
                  created_at: token.inserted_at,
                  last_used_at: token.last_used_at,
                  expires_at: token.expires_at,
                  device_info: token.device_info,
                  ip_address: token.ip_address
                }
              end)
          }
        })

      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(Errors.error_response(Errors.not_authenticated()))
    end
  end

  @doc """
  Revoke a specific session by token ID
  """
  def revoke_session(conn, %{"id" => token_id}) do
    case conn.assigns[:current_user] do
      %User{} = user ->
        token_id = String.to_integer(token_id)

        case Accounts.get_auth_token_by_hash("") do
          nil ->
            # Try to find by ID in user's tokens
            tokens = Accounts.list_user_tokens(user.id)
            token = Enum.find(tokens, fn t -> t.id == token_id end)

            if token do
              Accounts.blacklist_token(
                token.token_hash,
                user.id,
                "manual_revocation",
                token.expires_at
              )

              Accounts.delete_auth_token(token)

              conn
              |> json(%{
                success: true,
                message: "Session revoked successfully"
              })
            else
              conn
              |> put_status(:not_found)
              |> json(Errors.error_response(Errors.session_not_found()))
            end

          _ ->
            conn
            |> put_status(:not_found)
            |> json(Errors.error_response(Errors.session_not_found()))
        end

      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(Errors.error_response(Errors.not_authenticated()))
    end
  rescue
    ArgumentError ->
      conn
      |> put_status(:bad_request)
      |> json(Errors.error_response(Errors.invalid_token_id()))
  end

  # Private functions

  defp get_current_user(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        case Accounts.verify_token(token, "access") do
          {:ok, user, _token} -> user
          {:error, _reason} -> nil
        end

      _ ->
        nil
    end
  rescue
    Ecto.NoResultsError -> nil
  end

  defp generate_token_pair(user, conn) do
    token_salt = Application.get_env(:shadowfax, :token_salt, "user_auth_token")
    token_version = get_token_version()

    # Generate access token
    access_token =
      Phoenix.Token.sign(
        ShadowfaxWeb.Endpoint,
        token_salt,
        %{user_id: user.id, type: "access", version: token_version}
      )

    # Generate refresh token
    refresh_token =
      Phoenix.Token.sign(
        ShadowfaxWeb.Endpoint,
        token_salt,
        %{user_id: user.id, type: "refresh", version: token_version}
      )

    # Store tokens in database
    access_token_hash = AuthToken.hash_token(access_token)
    refresh_token_hash = AuthToken.hash_token(refresh_token)

    device_info = extract_device_info(conn)
    ip_address = get_client_ip(conn)

    # Store access token
    Accounts.create_auth_token(%{
      user_id: user.id,
      token_hash: access_token_hash,
      token_type: "access",
      token_version: token_version,
      expires_at: AuthToken.calculate_expiration("access"),
      device_info: device_info,
      ip_address: ip_address
    })

    # Store refresh token
    Accounts.create_auth_token(%{
      user_id: user.id,
      token_hash: refresh_token_hash,
      token_type: "refresh",
      token_version: token_version,
      expires_at: AuthToken.calculate_expiration("refresh"),
      device_info: device_info,
      ip_address: ip_address
    })

    {:ok, access_token, refresh_token}
  end

  defp get_token_version do
    # Token version for rotation support
    Application.get_env(:shadowfax, :token_version, 1)
  end

  defp extract_device_info(conn) do
    user_agent = get_req_header(conn, "user-agent") |> List.first()

    %{
      user_agent: user_agent
    }
  end

  defp get_client_ip(conn) do
    case get_req_header(conn, "x-forwarded-for") do
      [ip | _] -> ip
      [] -> to_string(:inet_parse.ntoa(conn.remote_ip))
    end
  end

  defp serialize_user(%User{} = user) do
    %{
      id: user.id,
      username: user.username,
      email: user.email,
      first_name: user.first_name,
      last_name: user.last_name,
      avatar_url: user.avatar_url,
      status: user.status,
      display_name: User.display_name(user),
      inserted_at: user.inserted_at,
      updated_at: user.updated_at
    }
  end

  defp serialize_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
