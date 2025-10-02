defmodule ShadowfaxWeb.Plugs.AuthenticateTest do
  use ShadowfaxWeb.ConnCase, async: true

  alias ShadowfaxWeb.Plugs.Authenticate
  alias Shadowfax.Accounts

  setup do
    # Create a test user
    {:ok, user} =
      Accounts.create_user(%{
        username: "testuser",
        email: "test@example.com",
        password: "TestPassword123!",
        first_name: "Test",
        last_name: "User"
      })

    # Generate a valid token
    token = Phoenix.Token.sign(ShadowfaxWeb.Endpoint, "user auth", user.id)

    {:ok, user: user, token: token}
  end

  describe "authenticate plug" do
    test "allows request with valid token", %{conn: conn, user: user, token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> Authenticate.call([])

      assert conn.assigns.current_user.id == user.id
      refute conn.halted
    end

    test "rejects request without authorization header", %{conn: conn} do
      conn = Authenticate.call(conn, [])

      assert conn.halted
      assert conn.status == 401

      assert json_response(conn, 401) == %{
               "success" => false,
               "error" => "Authentication required"
             }
    end

    test "rejects request with invalid token format", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "InvalidFormat")
        |> Authenticate.call([])

      assert conn.halted
      assert conn.status == 401
    end

    test "rejects request with expired token", %{conn: conn, user: user} do
      # Create an expired token (max_age is 2 weeks, so we sign with old timestamp)
      expired_token =
        Phoenix.Token.sign(
          ShadowfaxWeb.Endpoint,
          "user auth",
          user.id,
          # Older than 2 weeks
          signed_at: System.system_time(:second) - 1_209_601
        )

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{expired_token}")
        |> Authenticate.call([])

      assert conn.halted
      assert conn.status == 401
    end

    test "rejects request with invalid token signature", %{conn: conn} do
      invalid_token = "SFMyNTY.invalid.token"

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{invalid_token}")
        |> Authenticate.call([])

      assert conn.halted
      assert conn.status == 401
    end

    test "rejects request with token for non-existent user", %{conn: conn} do
      # Create token for user ID that doesn't exist
      fake_token = Phoenix.Token.sign(ShadowfaxWeb.Endpoint, "user auth", 999_999)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{fake_token}")
        |> Authenticate.call([])

      assert conn.halted
      assert conn.status == 401
    end

    test "rejects request with malformed bearer token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer")
        |> Authenticate.call([])

      assert conn.halted
      assert conn.status == 401
    end
  end
end
