defmodule ShadowfaxWeb.Plugs.RateLimitTest do
  use ShadowfaxWeb.ConnCase, async: false

  alias ShadowfaxWeb.Plugs.{RateLimitAuth, RateLimitMessages, RateLimitAPI}
  alias Shadowfax.Accounts

  setup do
    # Clear Hammer backend before each test by deleting old buckets
    # We use a date far in the future to delete all buckets
    future_time = DateTime.add(DateTime.utc_now(), 365 * 24 * 60 * 60, :second)

    try do
      Hammer.Backend.ETS.delete_buckets(:hammer_backend_ets_table, future_time)
    rescue
      _ -> :ok
    end

    :ok
  end

  describe "RateLimitAuth" do
    test "allows requests under the limit", %{conn: _conn} do
      # RateLimitAuth limit is 5 requests per minute
      # Use unique IP for this test
      test_ip = {10, 0, Enum.random(1..254), Enum.random(1..254)}

      for _i <- 1..5 do
        conn = build_conn(:post, "/api/auth/login") |> Map.put(:remote_ip, test_ip)
        conn = RateLimitAuth.call(conn, RateLimitAuth.init([]))
        refute conn.halted
      end
    end

    test "blocks requests over the limit", %{conn: _conn} do
      # Use unique IP for this test
      test_ip = {10, 1, Enum.random(1..254), Enum.random(1..254)}

      # Make 5 requests (the limit)
      for _i <- 1..5 do
        conn = build_conn(:post, "/api/auth/login") |> Map.put(:remote_ip, test_ip)
        conn = RateLimitAuth.call(conn, RateLimitAuth.init([]))
        refute conn.halted
      end

      # 6th request should be blocked
      conn = build_conn(:post, "/api/auth/login") |> Map.put(:remote_ip, test_ip)
      conn = RateLimitAuth.call(conn, RateLimitAuth.init([]))

      assert conn.halted
      assert conn.status == 429

      assert %{
               "success" => false,
               "error" => "Rate limit exceeded. Please try again later."
             } = json_response(conn, 429)
    end

    test "rate limits by IP address", %{conn: _conn} do
      # Use unique IPs for this test
      ip1 = {10, 2, Enum.random(1..254), Enum.random(1..254)}
      ip2 = {10, 3, Enum.random(1..254), Enum.random(1..254)}

      for _i <- 1..5 do
        new_conn = build_conn(:post, "/api/auth/login") |> Map.put(:remote_ip, ip1)
        result = RateLimitAuth.call(new_conn, RateLimitAuth.init([]))
        refute result.halted
      end

      # 6th request from same IP should be blocked
      conn_blocked = build_conn(:post, "/api/auth/login") |> Map.put(:remote_ip, ip1)
      result = RateLimitAuth.call(conn_blocked, RateLimitAuth.init([]))
      assert result.halted

      # Different IP should still work
      conn2 = build_conn(:post, "/api/auth/login") |> Map.put(:remote_ip, ip2)
      result = RateLimitAuth.call(conn2, RateLimitAuth.init([]))
      refute result.halted
    end
  end

  describe "RateLimitMessages" do
    setup do
      {:ok, user} =
        Accounts.create_user(%{
          username: "ratelimituser",
          email: "ratelimit@example.com",
          password: "RateLimit123!",
          first_name: "Rate",
          last_name: "Limit"
        })

      {:ok, user: user}
    end

    test "allows requests under the limit for authenticated users", %{user: user} do
      # RateLimitMessages limit is 30 requests per minute
      for _i <- 1..30 do
        new_conn = build_conn(:post, "/api/channels/1/messages") |> assign(:current_user, user)
        result = RateLimitMessages.call(new_conn, RateLimitMessages.init([]))
        refute result.halted
      end
    end

    test "blocks requests over the limit for authenticated users", %{user: user} do
      # Make 30 requests (the limit)
      for _i <- 1..30 do
        new_conn = build_conn(:post, "/api/channels/1/messages") |> assign(:current_user, user)
        result = RateLimitMessages.call(new_conn, RateLimitMessages.init([]))
        refute result.halted
      end

      # 31st request should be blocked
      new_conn = build_conn(:post, "/api/channels/1/messages") |> assign(:current_user, user)
      result = RateLimitMessages.call(new_conn, RateLimitMessages.init([]))

      assert result.halted
      assert result.status == 429
    end

    test "rate limits by user ID for authenticated requests", %{conn: _conn} do
      {:ok, user1} =
        Accounts.create_user(%{
          username: "user1",
          email: "user1@example.com",
          password: "Password123!",
          first_name: "User",
          last_name: "One"
        })

      {:ok, user2} =
        Accounts.create_user(%{
          username: "user2",
          email: "user2@example.com",
          password: "Password123!",
          first_name: "User",
          last_name: "Two"
        })

      # User 1 makes 30 requests
      for _i <- 1..30 do
        new_conn = build_conn(:post, "/api/channels/1/messages") |> assign(:current_user, user1)
        result = RateLimitMessages.call(new_conn, RateLimitMessages.init([]))
        refute result.halted
      end

      # User 1's 31st request should be blocked
      conn_blocked = build_conn(:post, "/api/channels/1/messages") |> assign(:current_user, user1)
      result = RateLimitMessages.call(conn_blocked, RateLimitMessages.init([]))
      assert result.halted

      # User 2 should still be able to make requests
      conn_user2 = build_conn(:post, "/api/channels/1/messages") |> assign(:current_user, user2)
      result = RateLimitMessages.call(conn_user2, RateLimitMessages.init([]))
      refute result.halted
    end

    test "rate limits by IP for unauthenticated requests", %{conn: _conn} do
      test_ip = {10, 0, 0, 1}

      # Make 30 requests from same IP
      for _i <- 1..30 do
        new_conn = build_conn(:post, "/api/channels/1/messages") |> Map.put(:remote_ip, test_ip)
        result = RateLimitMessages.call(new_conn, RateLimitMessages.init([]))
        refute result.halted
      end

      # 31st request should be blocked
      conn_blocked = build_conn(:post, "/api/channels/1/messages") |> Map.put(:remote_ip, test_ip)

      result = RateLimitMessages.call(conn_blocked, RateLimitMessages.init([]))
      assert result.halted
    end
  end

  describe "RateLimitAPI" do
    setup do
      {:ok, user} =
        Accounts.create_user(%{
          username: "apiuser",
          email: "api@example.com",
          password: "ApiUser123!",
          first_name: "API",
          last_name: "User"
        })

      {:ok, user: user}
    end

    test "allows requests under the limit", %{user: user} do
      # RateLimitAPI limit is 100 requests per minute
      for _i <- 1..100 do
        new_conn = build_conn(:get, "/api/channels") |> assign(:current_user, user)
        result = RateLimitAPI.call(new_conn, RateLimitAPI.init([]))
        refute result.halted
      end
    end

    test "blocks requests over the limit", %{user: user} do
      # Make 100 requests (the limit)
      for _i <- 1..100 do
        new_conn = build_conn(:get, "/api/channels") |> assign(:current_user, user)
        result = RateLimitAPI.call(new_conn, RateLimitAPI.init([]))
        refute result.halted
      end

      # 101st request should be blocked
      new_conn = build_conn(:get, "/api/channels") |> assign(:current_user, user)
      result = RateLimitAPI.call(new_conn, RateLimitAPI.init([]))

      assert result.halted
      assert result.status == 429

      assert %{
               "success" => false,
               "error" => "Rate limit exceeded. Please try again later."
             } = json_response(result, 429)
    end

    test "rate limits by user ID for authenticated requests", %{conn: _conn} do
      {:ok, user1} =
        Accounts.create_user(%{
          username: "apiuser1",
          email: "apiuser1@example.com",
          password: "Password123!",
          first_name: "API",
          last_name: "User1"
        })

      {:ok, user2} =
        Accounts.create_user(%{
          username: "apiuser2",
          email: "apiuser2@example.com",
          password: "Password123!",
          first_name: "API",
          last_name: "User2"
        })

      # User 1 makes 100 requests
      for _i <- 1..100 do
        new_conn = build_conn(:get, "/api/channels") |> assign(:current_user, user1)
        result = RateLimitAPI.call(new_conn, RateLimitAPI.init([]))
        refute result.halted
      end

      # User 1's 101st request should be blocked
      conn_blocked = build_conn(:get, "/api/channels") |> assign(:current_user, user1)
      result = RateLimitAPI.call(conn_blocked, RateLimitAPI.init([]))
      assert result.halted

      # User 2 should still be able to make requests
      conn_user2 = build_conn(:get, "/api/channels") |> assign(:current_user, user2)
      result = RateLimitAPI.call(conn_user2, RateLimitAPI.init([]))
      refute result.halted
    end
  end
end
