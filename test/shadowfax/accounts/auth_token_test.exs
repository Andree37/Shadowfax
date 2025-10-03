defmodule Shadowfax.Accounts.AuthTokenTest do
  use Shadowfax.DataCase

  alias Shadowfax.Accounts.AuthToken

  describe "changeset/2" do
    test "valid changeset with required fields" do
      attrs = %{
        user_id: 1,
        token_hash: "abc123",
        token_type: "access",
        token_version: 1,
        expires_at: DateTime.utc_now() |> DateTime.add(900, :second)
      }

      changeset = AuthToken.changeset(%AuthToken{}, attrs)
      assert changeset.valid?
    end

    test "requires user_id" do
      attrs = %{
        token_hash: "abc123",
        token_type: "access",
        token_version: 1,
        expires_at: DateTime.utc_now() |> DateTime.add(900, :second)
      }

      changeset = AuthToken.changeset(%AuthToken{}, attrs)
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires token_hash" do
      attrs = %{
        user_id: 1,
        token_type: "access",
        token_version: 1,
        expires_at: DateTime.utc_now() |> DateTime.add(900, :second)
      }

      changeset = AuthToken.changeset(%AuthToken{}, attrs)
      assert %{token_hash: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates token_type is in allowed list" do
      attrs = %{
        user_id: 1,
        token_hash: "abc123",
        token_type: "invalid",
        token_version: 1,
        expires_at: DateTime.utc_now() |> DateTime.add(900, :second)
      }

      changeset = AuthToken.changeset(%AuthToken{}, attrs)
      assert %{token_type: ["is invalid"]} = errors_on(changeset)
    end

    test "validates token_version is greater than 0" do
      attrs = %{
        user_id: 1,
        token_hash: "abc123",
        token_type: "access",
        token_version: 0,
        expires_at: DateTime.utc_now() |> DateTime.add(900, :second)
      }

      changeset = AuthToken.changeset(%AuthToken{}, attrs)
      assert %{token_version: ["must be greater than 0"]} = errors_on(changeset)
    end

    test "accepts optional fields" do
      attrs = %{
        user_id: 1,
        token_hash: "abc123",
        token_type: "access",
        token_version: 1,
        expires_at: DateTime.utc_now() |> DateTime.add(900, :second),
        last_used_at: DateTime.utc_now(),
        device_info: %{"user_agent" => "Mozilla/5.0"},
        ip_address: "192.168.1.1"
      }

      changeset = AuthToken.changeset(%AuthToken{}, attrs)
      assert changeset.valid?
    end
  end

  describe "get_ttl/1" do
    test "returns correct TTL for access token" do
      assert AuthToken.get_ttl("access") == 900
    end

    test "returns correct TTL for refresh token" do
      assert AuthToken.get_ttl("refresh") == 2_592_000
    end

    test "returns default TTL for unknown token type" do
      assert AuthToken.get_ttl("unknown") == 900
    end
  end

  describe "calculate_expiration/1" do
    test "calculates correct expiration for access token" do
      now = DateTime.utc_now()
      expires_at = AuthToken.calculate_expiration("access")

      difference = DateTime.diff(expires_at, now, :second)
      assert difference >= 899 and difference <= 901
    end

    test "calculates correct expiration for refresh token" do
      now = DateTime.utc_now()
      expires_at = AuthToken.calculate_expiration("refresh")

      difference = DateTime.diff(expires_at, now, :second)
      assert difference >= 2_591_999 and difference <= 2_592_001
    end
  end

  describe "expired?/1" do
    test "returns true for expired token" do
      token = %AuthToken{
        expires_at: DateTime.utc_now() |> DateTime.add(-1, :second)
      }

      assert AuthToken.expired?(token)
    end

    test "returns false for non-expired token" do
      token = %AuthToken{
        expires_at: DateTime.utc_now() |> DateTime.add(900, :second)
      }

      refute AuthToken.expired?(token)
    end

    test "returns true for token expiring exactly now" do
      # Truncate to second to avoid microsecond precision issues
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      token = %AuthToken{
        expires_at: now
      }

      # Token expiring exactly now should be considered expired
      assert AuthToken.expired?(token)
    end
  end

  describe "valid?/1" do
    test "returns true for valid token" do
      token = %AuthToken{
        expires_at: DateTime.utc_now() |> DateTime.add(900, :second)
      }

      assert AuthToken.valid?(token)
    end

    test "returns false for expired token" do
      token = %AuthToken{
        expires_at: DateTime.utc_now() |> DateTime.add(-1, :second)
      }

      refute AuthToken.valid?(token)
    end
  end

  describe "hash_token/1" do
    test "hashes token string consistently" do
      token = "my_secret_token"
      hash1 = AuthToken.hash_token(token)
      hash2 = AuthToken.hash_token(token)

      assert hash1 == hash2
      assert is_binary(hash1)
      assert String.length(hash1) == 64
    end

    test "produces different hashes for different tokens" do
      token1 = "token1"
      token2 = "token2"

      hash1 = AuthToken.hash_token(token1)
      hash2 = AuthToken.hash_token(token2)

      assert hash1 != hash2
    end

    test "produces lowercase hex string" do
      token = "my_token"
      hash = AuthToken.hash_token(token)

      assert hash =~ ~r/^[a-f0-9]{64}$/
    end
  end
end
