defmodule ShadowfaxWeb.Plugs.AuthenticateNewTest do
  use ShadowfaxWeb.ConnCase, async: true

  alias Shadowfax.Accounts
  alias Shadowfax.Accounts.AuthToken
  alias ShadowfaxWeb.Plugs.Authenticate
  alias ShadowfaxWeb.Errors

  setup do
    {:ok, user} =
      Accounts.create_user(%{
        username: "plugtest_#{System.unique_integer([:positive])}",
        email: "plugtest#{System.unique_integer([:positive])}@example.com",
        password: "Password123!",
        first_name: "Plug",
        last_name: "Test"
      })

    # Create a valid token
    token_string = "test_token_#{System.unique_integer([:positive])}"
    token_hash = AuthToken.hash_token(token_string)

    {:ok, auth_token} =
      Accounts.create_auth_token(%{
        user_id: user.id,
        token_hash: token_hash,
        token_type: "access",
        token_version: 1,
        expires_at: DateTime.utc_now() |> DateTime.add(900, :second)
      })

    {:ok, user: user, token: token_string, auth_token: auth_token}
  end

  describe "call/2 with valid token" do
    test "assigns current_user to conn", %{conn: conn, user: user, token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> Authenticate.call([])

      assert conn.assigns.current_user.id == user.id
      assert conn.assigns.current_user_id == user.id
      refute conn.halted
    end

    test "updates token last_used_at", %{conn: conn, token: token, auth_token: auth_token} do
      initial_last_used = auth_token.last_used_at

      conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> Authenticate.call([])

      token_hash = AuthToken.hash_token(token)
      updated_token = Accounts.get_auth_token_by_hash(token_hash)

      assert updated_token.last_used_at != initial_last_used
      assert updated_token.last_used_at != nil
    end
  end

  describe "call/2 with invalid token" do
    test "halts with 401 for missing authorization header", %{conn: conn} do
      conn = Authenticate.call(conn, [])

      assert conn.halted
      assert conn.status == 401

      response = json_response(conn, 401)
      assert response["success"] == false
      assert response["error"] == Errors.missing_authorization()
    end

    test "halts with 401 for malformed authorization header", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "InvalidFormat token")
        |> Authenticate.call([])

      assert conn.halted
      assert conn.status == 401
    end

    test "halts with 401 for non-existent token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer nonexistent_token")
        |> Authenticate.call([])

      assert conn.halted
      assert conn.status == 401

      response = json_response(conn, 401)
      assert response["success"] == false
      assert response["error"] == Errors.invalid_token()
    end

    test "halts with 401 for expired token", %{conn: conn, user: user} do
      # Create expired token
      expired_token_string = "expired_token_#{System.unique_integer([:positive])}"
      token_hash = AuthToken.hash_token(expired_token_string)

      Accounts.create_auth_token(%{
        user_id: user.id,
        token_hash: token_hash,
        token_type: "access",
        token_version: 1,
        expires_at: DateTime.utc_now() |> DateTime.add(-100, :second)
      })

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{expired_token_string}")
        |> Authenticate.call([])

      assert conn.halted
      assert conn.status == 401

      response = json_response(conn, 401)
      assert response["success"] == false
      assert response["error"] == Errors.token_expired()
    end

    test "halts with 401 for blacklisted token", %{conn: conn, user: user, token: token} do
      # Blacklist the token
      token_hash = AuthToken.hash_token(token)

      Accounts.blacklist_token(
        token_hash,
        user.id,
        "test_blacklist",
        DateTime.utc_now() |> DateTime.add(900, :second)
      )

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> Authenticate.call([])

      assert conn.halted
      assert conn.status == 401

      response = json_response(conn, 401)
      assert response["success"] == false
      assert response["error"] == Errors.token_revoked()
    end

    test "halts with 401 for refresh token used as access token", %{conn: conn, user: user} do
      # Create refresh token
      refresh_token_string = "refresh_token_#{System.unique_integer([:positive])}"
      token_hash = AuthToken.hash_token(refresh_token_string)

      Accounts.create_auth_token(%{
        user_id: user.id,
        token_hash: token_hash,
        token_type: "refresh",
        token_version: 1,
        expires_at:
          DateTime.utc_now() |> DateTime.add(2_592_000, :second) |> DateTime.truncate(:second)
      })

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{refresh_token_string}")
        |> Authenticate.call([])

      assert conn.halted
      assert conn.status == 401

      response = json_response(conn, 401)
      assert response["success"] == false
      # Refresh tokens cannot be used as access tokens
      assert response["error"] == Errors.invalid_token_type()
    end
  end

  describe "call/2 error response format" do
    test "returns JSON error response", %{conn: conn} do
      conn = Authenticate.call(conn, [])

      assert conn.halted
      assert get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]

      response = json_response(conn, 401)
      assert is_map(response)
      assert Map.has_key?(response, "success")
      assert Map.has_key?(response, "error")
      assert response["success"] == false
    end

    test "includes descriptive error messages", %{conn: conn, user: user} do
      # Test different error scenarios
      test_cases = [
        {
          Errors.missing_authorization(),
          fn c -> c end
        },
        {
          Errors.invalid_token(),
          fn c -> put_req_header(c, "authorization", "Bearer invalid_token") end
        },
        {
          Errors.token_expired(),
          fn c ->
            expired_token = "expired_#{System.unique_integer([:positive])}"
            token_hash = AuthToken.hash_token(expired_token)

            Accounts.create_auth_token(%{
              user_id: user.id,
              token_hash: token_hash,
              token_type: "access",
              token_version: 1,
              expires_at: DateTime.utc_now() |> DateTime.add(-1, :second)
            })

            put_req_header(c, "authorization", "Bearer #{expired_token}")
          end
        }
      ]

      for {expected_error, setup_fn} <- test_cases do
        test_conn =
          conn
          |> setup_fn.()
          |> Authenticate.call([])

        response = json_response(test_conn, 401)
        assert response["error"] == expected_error
      end
    end
  end
end
