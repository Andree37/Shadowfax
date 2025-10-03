defmodule ShadowfaxWeb.RateLimitIntegrationTest do
  use ShadowfaxWeb.ConnCase, async: false

  alias Shadowfax.Accounts

  setup %{conn: conn} do
    # Clear Hammer backend before each test by deleting old buckets
    # We use a date far in the future to delete all buckets
    future_time = DateTime.add(DateTime.utc_now(), 365 * 24 * 60 * 60, :second)

    try do
      Hammer.Backend.ETS.delete_buckets(:hammer_backend_ets_table, future_time)
    rescue
      _ -> :ok
    end

    # Use unique IP for each test to avoid interference
    unique_ip = {10, 20, Enum.random(1..254), Enum.random(1..254)}
    conn = %{conn | remote_ip: unique_ip}

    {:ok, conn: conn}
  end

  describe "Auth endpoint rate limiting" do
    test "POST /api/auth/login enforces rate limit of 5 requests per minute", %{conn: conn} do
      # First 5 login attempts should succeed (or return 401 for wrong password)
      for i <- 1..5 do
        response =
          conn
          |> post(~p"/api/auth/login", %{
            email: "test#{i}@example.com",
            password: "password"
          })

        # Should not be rate limited (but may be 401 for invalid credentials)
        assert response.status in [401, 200]
      end

      # 6th request should be rate limited
      response =
        conn
        |> post(~p"/api/auth/login", %{email: "test@example.com", password: "password"})

      assert response.status == 429

      assert %{
               "success" => false,
               "error" => "Rate limit exceeded. Please try again later."
             } = json_response(response, 429)
    end

    test "POST /api/auth/register enforces rate limit of 5 requests per minute", %{conn: conn} do
      # First 5 registration attempts
      for i <- 1..5 do
        response =
          conn
          |> post(~p"/api/auth/register", %{
            user: %{
              username: "user#{i}_#{:rand.uniform(10000)}",
              email: "user#{i}_#{:rand.uniform(10000)}@example.com",
              password: "Password123!",
              first_name: "Test",
              last_name: "User"
            }
          })

        # Should not be rate limited (may succeed or fail validation)
        assert response.status in [201, 422]
      end

      # 6th request should be rate limited
      response =
        conn
        |> post(~p"/api/auth/register", %{
          user: %{
            username: "user6_#{:rand.uniform(10000)}",
            email: "user6_#{:rand.uniform(10000)}@example.com",
            password: "Password123!",
            first_name: "Test",
            last_name: "User"
          }
        })

      assert response.status == 429
    end

    test "rate limit is per IP address", %{conn: conn} do
      # Make 5 requests from first IP
      conn1 = %{conn | remote_ip: {192, 168, 1, 100}}

      for _i <- 1..5 do
        post(conn1, ~p"/api/auth/login", %{email: "test@example.com", password: "password"})
      end

      # 6th request from same IP should be blocked
      response =
        post(conn1, ~p"/api/auth/login", %{email: "test@example.com", password: "password"})

      assert response.status == 429

      # Request from different IP should work
      conn2 = %{conn | remote_ip: {192, 168, 1, 101}}

      response =
        post(conn2, ~p"/api/auth/login", %{email: "test@example.com", password: "password"})

      assert response.status in [401, 200]
    end
  end

  describe "Message endpoint rate limiting" do
    setup do
      {:ok, user} =
        Accounts.create_user(%{
          username: "messageuser",
          email: "messageuser@example.com",
          password: "Password123!",
          first_name: "Message",
          last_name: "User"
        })

      token = Phoenix.Token.sign(ShadowfaxWeb.Endpoint, "user auth", user.id)

      # Create a channel for testing
      {:ok, channel} =
        Shadowfax.Chat.create_channel(%{
          name: "test-channel",
          description: "Test channel",
          is_private: false,
          created_by_id: user.id
        })

      {:ok, user: user, token: token, channel: channel}
    end

    test "POST /api/channels/:id/messages enforces rate limit of 30 requests per minute",
         %{conn: conn, token: token, channel: channel} do
      conn = put_req_header(conn, "authorization", "Bearer #{token}")

      # First 30 message attempts should not be rate limited
      for i <- 1..30 do
        response =
          conn
          |> post(~p"/api/channels/#{channel.id}/messages", %{
            message: %{content: "Test message #{i}"}
          })

        # Should succeed or fail for other reasons, but not rate limiting
        assert response.status in [201, 403, 422]
      end

      # 31st request should be rate limited
      response =
        conn
        |> post(~p"/api/channels/#{channel.id}/messages", %{
          message: %{content: "Test message 31"}
        })

      assert response.status == 429

      assert %{
               "success" => false,
               "error" => "Rate limit exceeded. Please try again later."
             } = json_response(response, 429)
    end

    test "message rate limit is per user ID", %{conn: conn, channel: channel} do
      {:ok, user1} =
        Accounts.create_user(%{
          username: "msguser1",
          email: "msguser1@example.com",
          password: "Password123!",
          first_name: "Msg",
          last_name: "User1"
        })

      {:ok, user2} =
        Accounts.create_user(%{
          username: "msguser2",
          email: "msguser2@example.com",
          password: "Password123!",
          first_name: "Msg",
          last_name: "User2"
        })

      token1 = Phoenix.Token.sign(ShadowfaxWeb.Endpoint, "user auth", user1.id)
      token2 = Phoenix.Token.sign(ShadowfaxWeb.Endpoint, "user auth", user2.id)

      conn1 = put_req_header(conn, "authorization", "Bearer #{token1}")
      conn2 = put_req_header(conn, "authorization", "Bearer #{token2}")

      # User 1 makes 30 requests
      for i <- 1..30 do
        post(conn1, ~p"/api/channels/#{channel.id}/messages", %{
          message: %{content: "User 1 message #{i}"}
        })
      end

      # User 1's 31st request should be blocked
      response =
        post(conn1, ~p"/api/channels/#{channel.id}/messages", %{
          message: %{content: "User 1 message 31"}
        })

      assert response.status == 429

      # User 2 should still be able to post
      response =
        post(conn2, ~p"/api/channels/#{channel.id}/messages", %{
          message: %{content: "User 2 message"}
        })

      assert response.status in [201, 403, 422]
    end
  end

  describe "General API rate limiting" do
    setup do
      {:ok, user} =
        Accounts.create_user(%{
          username: "apiuser",
          email: "apiuser@example.com",
          password: "Password123!",
          first_name: "API",
          last_name: "User"
        })

      token = Phoenix.Token.sign(ShadowfaxWeb.Endpoint, "user auth", user.id)

      {:ok, user: user, token: token}
    end

    test "enforces rate limit of 100 requests per minute on general API endpoints",
         %{conn: conn, token: token} do
      conn = put_req_header(conn, "authorization", "Bearer #{token}")

      # First 100 requests should not be rate limited
      for _i <- 1..100 do
        response = get(conn, ~p"/api/channels")
        # Should succeed, but not be rate limited
        assert response.status in [200, 401, 403]
      end

      # 101st request should be rate limited
      response = get(conn, ~p"/api/channels")
      assert response.status == 429

      assert %{
               "success" => false,
               "error" => "Rate limit exceeded. Please try again later."
             } = json_response(response, 429)
    end

    test "API rate limit applies to all authenticated endpoints",
         %{conn: conn, token: token} do
      conn = put_req_header(conn, "authorization", "Bearer #{token}")

      # Mix of different endpoints should all count toward the same limit
      endpoints = [
        {&get/2, ~p"/api/channels"},
        {&get/2, ~p"/api/auth/me"},
        {&get/2, ~p"/api/users"}
      ]

      # Make 100 requests across different endpoints
      for i <- 1..100 do
        {method, path} = Enum.at(endpoints, rem(i, length(endpoints)))
        response = method.(conn, path)
        assert response.status in [200, 401, 403, 404]
      end

      # 101st request should be rate limited regardless of endpoint
      response = get(conn, ~p"/api/auth/me")
      assert response.status == 429
    end
  end

  describe "Multiple rate limits interaction" do
    setup do
      {:ok, user} =
        Accounts.create_user(%{
          username: "multiuser",
          email: "multiuser@example.com",
          password: "Password123!",
          first_name: "Multi",
          last_name: "User"
        })

      token = Phoenix.Token.sign(ShadowfaxWeb.Endpoint, "user auth", user.id)

      {:ok, channel} =
        Shadowfax.Chat.create_channel(%{
          name: "test-channel",
          description: "Test channel",
          is_private: false,
          created_by_id: user.id
        })

      {:ok, user: user, token: token, channel: channel}
    end

    test "message rate limit is enforced before general API rate limit",
         %{conn: conn, token: token, channel: channel} do
      conn = put_req_header(conn, "authorization", "Bearer #{token}")

      # Make 30 message requests (message limit)
      for i <- 1..30 do
        post(conn, ~p"/api/channels/#{channel.id}/messages", %{
          message: %{content: "Message #{i}"}
        })
      end

      # 31st message should be blocked by message rate limit (not general API limit)
      response =
        post(conn, ~p"/api/channels/#{channel.id}/messages", %{
          message: %{content: "Message 31"}
        })

      assert response.status == 429

      # But other API endpoints should still work (general API limit is 100)
      response = get(conn, ~p"/api/channels")
      assert response.status in [200, 403]
    end
  end
end
