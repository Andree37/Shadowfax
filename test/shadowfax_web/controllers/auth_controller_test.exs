defmodule ShadowfaxWeb.AuthControllerTest do
  use ShadowfaxWeb.ConnCase, async: true

  alias Shadowfax.Accounts

  setup %{conn: conn} do
    # Use unique IP for each test to avoid rate limiting interference
    unique_ip = {127, 0, 0, Enum.random(1..254)}
    conn = %{conn | remote_ip: unique_ip}
    {:ok, conn: conn}
  end

  describe "POST /api/auth/register" do
    test "registers a new user with valid data", %{conn: conn} do
      user_params = %{
        username: "newuser",
        email: "newuser@example.com",
        password: "SecurePass123!",
        first_name: "New",
        last_name: "User"
      }

      conn = post(conn, ~p"/api/auth/register", %{user: user_params})

      assert %{
               "success" => true,
               "data" => %{
                 "user" => user,
                 "token" => token
               }
             } = json_response(conn, 201)

      assert user["username"] == "newuser"
      assert user["email"] == "newuser@example.com"
      assert is_binary(token)
      refute Map.has_key?(user, "password")
      refute Map.has_key?(user, "password_hash")
    end

    test "returns error with invalid data", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/register", %{user: %{username: ""}})

      assert %{"success" => false, "errors" => errors} = json_response(conn, 422)
      assert is_map(errors)
    end

    test "returns error with duplicate email", %{conn: conn} do
      user_params = %{
        username: "user1",
        email: "duplicate@example.com",
        password: "Password123!",
        first_name: "First",
        last_name: "User"
      }

      # Create first user
      {:ok, _user} = Accounts.create_user(user_params)

      # Try to create duplicate
      conn = post(conn, ~p"/api/auth/register", %{user: user_params})

      assert %{"success" => false, "errors" => _errors} = json_response(conn, 422)
    end
  end

  describe "POST /api/auth/login" do
    setup do
      {:ok, user} =
        Accounts.create_user(%{
          username: "loginuser",
          email: "login@example.com",
          password: "LoginPass123!",
          first_name: "Login",
          last_name: "User"
        })

      {:ok, user: user}
    end

    test "logs in user with valid credentials", %{conn: conn} do
      conn =
        post(conn, ~p"/api/auth/login", %{
          email: "login@example.com",
          password: "LoginPass123!"
        })

      assert %{
               "success" => true,
               "data" => %{
                 "user" => user,
                 "token" => token
               }
             } = json_response(conn, 200)

      assert user["email"] == "login@example.com"
      assert is_binary(token)
    end

    test "rejects login with invalid password", %{conn: conn} do
      conn =
        post(conn, ~p"/api/auth/login", %{
          email: "login@example.com",
          password: "WrongPassword"
        })

      assert %{
               "success" => false,
               "error" => "Invalid email or password"
             } = json_response(conn, 401)
    end

    test "rejects login with non-existent email", %{conn: conn} do
      conn =
        post(conn, ~p"/api/auth/login", %{
          email: "nonexistent@example.com",
          password: "Password123!"
        })

      assert %{
               "success" => false,
               "error" => "Invalid email or password"
             } = json_response(conn, 401)
    end

    test "returns error with missing credentials", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/login", %{})

      assert %{
               "success" => false,
               "error" => "Email and password are required"
             } = json_response(conn, 400)
    end
  end

  describe "GET /api/auth/me (authenticated)" do
    setup do
      {:ok, user} =
        Accounts.create_user(%{
          username: "meuser",
          email: "me@example.com",
          password: "MePass123!",
          first_name: "Me",
          last_name: "User"
        })

      token = Phoenix.Token.sign(ShadowfaxWeb.Endpoint, "user auth", user.id)

      {:ok, user: user, token: token}
    end

    test "returns current user with valid token", %{conn: conn, user: user, token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/auth/me")

      assert %{
               "success" => true,
               "data" => %{
                 "user" => returned_user
               }
             } = json_response(conn, 200)

      assert returned_user["id"] == user.id
      assert returned_user["email"] == user.email
    end

    test "rejects request without token", %{conn: conn} do
      conn = get(conn, ~p"/api/auth/me")

      assert %{
               "success" => false,
               "error" => "Authentication required"
             } = json_response(conn, 401)
    end
  end

  describe "DELETE /api/auth/logout (authenticated)" do
    setup do
      {:ok, user} =
        Accounts.create_user(%{
          username: "logoutuser",
          email: "logout@example.com",
          password: "LogoutPass123!",
          first_name: "Logout",
          last_name: "User"
        })

      token = Phoenix.Token.sign(ShadowfaxWeb.Endpoint, "user auth", user.id)

      {:ok, user: user, token: token}
    end

    test "logs out user with valid token", %{conn: conn, token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> delete(~p"/api/auth/logout")

      assert %{
               "success" => true,
               "message" => "Successfully logged out"
             } = json_response(conn, 200)
    end

    test "rejects logout without token", %{conn: conn} do
      conn = delete(conn, ~p"/api/auth/logout")

      assert %{
               "success" => false,
               "error" => "Authentication required"
             } = json_response(conn, 401)
    end
  end

  describe "GET /api/auth/verify (authenticated)" do
    setup do
      {:ok, user} =
        Accounts.create_user(%{
          username: "verifyuser",
          email: "verify@example.com",
          password: "VerifyPass123!",
          first_name: "Verify",
          last_name: "User"
        })

      token = Phoenix.Token.sign(ShadowfaxWeb.Endpoint, "user auth", user.id)

      {:ok, user: user, token: token}
    end

    test "verifies valid token", %{conn: conn, token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/auth/verify")

      assert %{
               "success" => true,
               "data" => %{
                 "valid" => true
               }
             } = json_response(conn, 200)
    end

    test "rejects invalid token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer invalid.token.here")
        |> get(~p"/api/auth/verify")

      assert %{
               "success" => false,
               "error" => "Authentication required"
             } = json_response(conn, 401)
    end
  end
end
