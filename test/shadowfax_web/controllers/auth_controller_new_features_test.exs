defmodule ShadowfaxWeb.AuthControllerNewFeaturesTest do
  use ShadowfaxWeb.ConnCase, async: true

  alias Shadowfax.Accounts
  alias Shadowfax.Accounts.AuthToken

  setup %{conn: conn} do
    # Use unique IP for each test to avoid rate limiting interference
    unique_ip = {127, 0, 0, Enum.random(1..254)}
    conn = %{conn | remote_ip: unique_ip}

    # Create a test user
    {:ok, user} =
      Accounts.create_user(%{
        username: "testuser_#{System.unique_integer([:positive])}",
        email: "test#{System.unique_integer([:positive])}@example.com",
        password: "Password123!",
        first_name: "Test",
        last_name: "User"
      })

    {:ok, conn: conn, user: user}
  end

  describe "POST /api/auth/register - token flow" do
    test "returns access_token and refresh_token on registration", %{conn: conn} do
      user_params = %{
        username: "newuser_#{System.unique_integer([:positive])}",
        email: "new#{System.unique_integer([:positive])}@example.com",
        password: "SecurePass123!",
        first_name: "New",
        last_name: "User"
      }

      conn = post(conn, ~p"/api/auth/register", %{user: user_params})

      assert %{
               "success" => true,
               "data" => %{
                 "user" => _user,
                 "access_token" => access_token,
                 "refresh_token" => refresh_token,
                 "token_type" => "Bearer",
                 "expires_in" => 900
               }
             } = json_response(conn, 201)

      assert is_binary(access_token)
      assert is_binary(refresh_token)
      assert access_token != refresh_token
    end

    test "stores tokens in database on registration", %{conn: conn} do
      user_params = %{
        username: "dbuser_#{System.unique_integer([:positive])}",
        email: "db#{System.unique_integer([:positive])}@example.com",
        password: "SecurePass123!",
        first_name: "DB",
        last_name: "User"
      }

      conn = post(conn, ~p"/api/auth/register", %{user: user_params})
      _response = json_response(conn, 201)

      user = Accounts.get_user_by_email(user_params.email)
      tokens = Accounts.list_user_tokens(user.id)

      assert length(tokens) == 2
      assert Enum.any?(tokens, &(&1.token_type == "access"))
      assert Enum.any?(tokens, &(&1.token_type == "refresh"))
    end
  end

  describe "POST /api/auth/login - token flow" do
    test "returns access_token and refresh_token on login", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/api/auth/login", %{
          email: user.email,
          password: "Password123!"
        })

      assert %{
               "success" => true,
               "data" => %{
                 "access_token" => access_token,
                 "refresh_token" => refresh_token,
                 "token_type" => "Bearer",
                 "expires_in" => 900
               }
             } = json_response(conn, 200)

      assert is_binary(access_token)
      assert is_binary(refresh_token)
    end
  end

  describe "POST /api/auth/refresh" do
    test "returns new tokens with valid refresh token", %{conn: conn, user: user} do
      # Login to get initial tokens
      login_conn =
        post(conn, ~p"/api/auth/login", %{
          email: user.email,
          password: "Password123!"
        })

      %{"data" => %{"refresh_token" => refresh_token}} = json_response(login_conn, 200)

      # Use refresh token to get new tokens
      refresh_conn = post(conn, ~p"/api/auth/refresh", %{refresh_token: refresh_token})

      assert %{
               "success" => true,
               "data" => %{
                 "access_token" => new_access_token,
                 "refresh_token" => new_refresh_token,
                 "token_type" => "Bearer",
                 "expires_in" => 900
               }
             } = json_response(refresh_conn, 200)

      assert is_binary(new_access_token)
      assert is_binary(new_refresh_token)
      assert new_refresh_token != refresh_token
    end

    test "rejects invalid refresh token", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/refresh", %{refresh_token: "invalid_token"})

      assert %{
               "success" => false,
               "error" => "Invalid or expired refresh token"
             } = json_response(conn, 401)
    end

    test "rejects access token used as refresh token", %{conn: conn, user: user} do
      # Login to get tokens
      login_conn =
        post(conn, ~p"/api/auth/login", %{
          email: user.email,
          password: "Password123!"
        })

      %{"data" => %{"access_token" => access_token}} = json_response(login_conn, 200)

      # Try to use access token as refresh token
      refresh_conn = post(conn, ~p"/api/auth/refresh", %{refresh_token: access_token})

      assert %{"success" => false} = json_response(refresh_conn, 401)
    end

    test "returns error when refresh_token is missing", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/refresh", %{})

      assert %{
               "success" => false,
               "error" => "Refresh token is required"
             } = json_response(conn, 400)
    end
  end

  describe "DELETE /api/auth/logout - blacklist functionality" do
    setup %{conn: conn, user: user} do
      # Login to get tokens
      login_conn =
        post(conn, ~p"/api/auth/login", %{
          email: user.email,
          password: "Password123!"
        })

      %{"data" => %{"access_token" => token}} = json_response(login_conn, 200)

      {:ok, token: token}
    end

    test "blacklists token on logout", %{conn: conn, token: token} do
      # Logout
      logout_conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> delete(~p"/api/auth/logout")

      assert %{"success" => true} = json_response(logout_conn, 200)

      # Try to use the token again
      me_conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/auth/me")

      assert %{"success" => false} = json_response(me_conn, 401)

      # Verify token is in blacklist
      token_hash = AuthToken.hash_token(token)
      assert Accounts.token_blacklisted?(token_hash)
    end

    test "deletes token from database on logout", %{conn: conn, token: token, user: user} do
      initial_count = length(Accounts.list_user_tokens(user.id))

      logout_conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> delete(~p"/api/auth/logout")

      assert %{"success" => true} = json_response(logout_conn, 200)

      final_count = length(Accounts.list_user_tokens(user.id))
      assert final_count < initial_count
    end

    test "revokes all tokens when logout_all is true", %{conn: conn, token: token, user: user} do
      # Create additional sessions
      post(conn, ~p"/api/auth/login", %{
        email: user.email,
        password: "Password123!"
      })

      initial_count = length(Accounts.list_user_tokens(user.id))
      assert initial_count > 1

      # Logout from all devices
      logout_conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> delete(~p"/api/auth/logout?logout_all=true")

      assert %{"success" => true} = json_response(logout_conn, 200)

      final_count = length(Accounts.list_user_tokens(user.id))
      assert final_count == 0
    end
  end

  describe "GET /api/auth/sessions" do
    test "lists all active sessions for user", %{conn: conn, user: user} do
      # Create multiple sessions
      login1 = post(conn, ~p"/api/auth/login", %{email: user.email, password: "Password123!"})
      %{"data" => %{"access_token" => token1}} = json_response(login1, 200)

      login2 = post(conn, ~p"/api/auth/login", %{email: user.email, password: "Password123!"})
      json_response(login2, 200)

      # Get sessions
      sessions_conn =
        conn
        |> put_req_header("authorization", "Bearer #{token1}")
        |> get(~p"/api/auth/sessions")

      assert %{
               "success" => true,
               "data" => %{
                 "sessions" => sessions
               }
             } = json_response(sessions_conn, 200)

      assert length(sessions) >= 2

      session = hd(sessions)
      assert Map.has_key?(session, "id")
      assert Map.has_key?(session, "token_type")
      assert Map.has_key?(session, "created_at")
      assert Map.has_key?(session, "expires_at")
    end

    test "requires authentication", %{conn: conn} do
      conn = get(conn, ~p"/api/auth/sessions")

      assert %{"success" => false} = json_response(conn, 401)
    end
  end

  describe "DELETE /api/auth/sessions/:id" do
    test "revokes specific session", %{conn: conn, user: user} do
      # Create two sessions
      login1 = post(conn, ~p"/api/auth/login", %{email: user.email, password: "Password123!"})
      %{"data" => %{"access_token" => token1}} = json_response(login1, 200)
      token1_hash = Shadowfax.Accounts.AuthToken.hash_token(token1)

      login2 = post(conn, ~p"/api/auth/login", %{email: user.email, password: "Password123!"})
      %{"data" => %{"access_token" => token2}} = json_response(login2, 200)

      # Get session list using token1
      sessions_conn =
        conn
        |> put_req_header("authorization", "Bearer #{token1}")
        |> get(~p"/api/auth/sessions")

      %{"data" => %{"sessions" => sessions}} = json_response(sessions_conn, 200)

      # Find token1's session specifically to revoke it
      token1_record = Shadowfax.Accounts.get_auth_token_by_hash(token1_hash)
      session_to_revoke = Enum.find(sessions, &(&1["id"] == token1_record.id))

      # Revoke token1's session using token1
      revoke_conn =
        conn
        |> put_req_header("authorization", "Bearer #{token1}")
        |> delete(~p"/api/auth/sessions/#{session_to_revoke["id"]}")

      assert %{"success" => true} = json_response(revoke_conn, 200)

      # token2 should still work since we only revoked token1
      me_conn =
        conn
        |> put_req_header("authorization", "Bearer #{token2}")
        |> get(~p"/api/auth/me")

      assert %{"success" => true} = json_response(me_conn, 200)
    end

    test "returns error for invalid session id", %{conn: conn, user: user} do
      login = post(conn, ~p"/api/auth/login", %{email: user.email, password: "Password123!"})
      %{"data" => %{"access_token" => token}} = json_response(login, 200)

      revoke_conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> delete(~p"/api/auth/sessions/99999")

      assert %{"success" => false} = json_response(revoke_conn, 404)
    end

    test "requires authentication", %{conn: conn} do
      conn = delete(conn, ~p"/api/auth/sessions/1")

      assert %{"success" => false} = json_response(conn, 401)
    end
  end

  describe "GET /api/auth/verify - renamed endpoint" do
    test "verifies valid token", %{conn: conn, user: user} do
      login = post(conn, ~p"/api/auth/login", %{email: user.email, password: "Password123!"})
      %{"data" => %{"access_token" => token}} = json_response(login, 200)

      verify_conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/auth/verify")

      assert %{
               "success" => true,
               "data" => %{
                 "user" => verified_user,
                 "valid" => true
               }
             } = json_response(verify_conn, 200)

      assert verified_user["id"] == user.id
    end

    test "rejects blacklisted token", %{conn: conn, user: user} do
      login = post(conn, ~p"/api/auth/login", %{email: user.email, password: "Password123!"})
      %{"data" => %{"access_token" => token}} = json_response(login, 200)

      # Logout to blacklist token
      conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> delete(~p"/api/auth/logout")

      # Try to verify blacklisted token
      verify_conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/auth/verify")

      assert %{"success" => false} = json_response(verify_conn, 401)
    end
  end
end
