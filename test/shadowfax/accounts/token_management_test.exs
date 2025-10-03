defmodule Shadowfax.Accounts.TokenManagementTest do
  use Shadowfax.DataCase

  alias Shadowfax.Accounts
  alias Shadowfax.Accounts.{AuthToken, TokenBlacklist}

  describe "create_auth_token/1" do
    test "creates auth token with valid attributes" do
      user = insert(:user)

      attrs = %{
        user_id: user.id,
        token_hash: "test_hash_123",
        token_type: "access",
        token_version: 1,
        expires_at: DateTime.utc_now() |> DateTime.add(900, :second) |> DateTime.truncate(:second)
      }

      assert {:ok, %AuthToken{} = token} = Accounts.create_auth_token(attrs)
      assert token.user_id == user.id
      assert token.token_hash == "test_hash_123"
      assert token.token_type == "access"
      assert token.token_version == 1
    end

    test "fails with invalid attributes" do
      attrs = %{
        token_hash: "test_hash",
        token_type: "access"
      }

      assert {:error, changeset} = Accounts.create_auth_token(attrs)
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "enforces unique token_hash constraint" do
      user = insert(:user)

      attrs = %{
        user_id: user.id,
        token_hash: "duplicate_hash",
        token_type: "access",
        token_version: 1,
        expires_at: DateTime.utc_now() |> DateTime.add(900, :second) |> DateTime.truncate(:second)
      }

      assert {:ok, _token} = Accounts.create_auth_token(attrs)
      assert {:error, changeset} = Accounts.create_auth_token(attrs)
      assert %{token_hash: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "get_auth_token_by_hash/1" do
    test "returns token when hash exists" do
      user = insert(:user)
      token = insert(:auth_token, user: user)

      result = Accounts.get_auth_token_by_hash(token.token_hash)
      assert result.id == token.id
      assert result.user.id == user.id
    end

    test "returns nil when hash doesn't exist" do
      result = Accounts.get_auth_token_by_hash("nonexistent_hash")
      assert is_nil(result)
    end
  end

  describe "list_user_tokens/1" do
    test "returns all active tokens for user" do
      user = insert(:user)
      token1 = insert(:auth_token, user: user, token_type: "access")
      token2 = insert(:auth_token, user: user, token_type: "refresh")

      tokens = Accounts.list_user_tokens(user.id)
      token_ids = Enum.map(tokens, & &1.id)

      assert length(tokens) == 2
      assert token1.id in token_ids
      assert token2.id in token_ids
    end

    test "excludes expired tokens" do
      user = insert(:user)
      _active_token = insert(:auth_token, user: user)

      _expired_token =
        insert(:auth_token,
          user: user,
          expires_at:
            DateTime.utc_now() |> DateTime.add(-1, :second) |> DateTime.truncate(:second)
        )

      tokens = Accounts.list_user_tokens(user.id)
      assert length(tokens) == 1
    end

    test "returns empty list when user has no tokens" do
      user = insert(:user)
      tokens = Accounts.list_user_tokens(user.id)
      assert tokens == []
    end

    test "only returns tokens for specified user" do
      user1 = insert(:user)
      user2 = insert(:user)
      _token1 = insert(:auth_token, user: user1)
      _token2 = insert(:auth_token, user: user2)

      tokens = Accounts.list_user_tokens(user1.id)
      assert length(tokens) == 1
      assert hd(tokens).user_id == user1.id
    end
  end

  describe "update_token_last_used/1" do
    test "updates last_used_at timestamp" do
      user = insert(:user)
      token = insert(:auth_token, user: user, last_used_at: nil)

      assert token.last_used_at == nil

      assert {:ok, updated_token} = Accounts.update_token_last_used(token)
      assert updated_token.last_used_at != nil
      assert DateTime.compare(updated_token.last_used_at, DateTime.utc_now()) in [:eq, :lt]
    end
  end

  describe "delete_auth_token/1" do
    test "deletes the token" do
      user = insert(:user)
      token = insert(:auth_token, user: user)

      assert {:ok, %AuthToken{}} = Accounts.delete_auth_token(token)
      assert is_nil(Accounts.get_auth_token_by_hash(token.token_hash))
    end
  end

  describe "delete_all_user_tokens/1" do
    test "deletes all tokens for user" do
      user = insert(:user)
      _token1 = insert(:auth_token, user: user)
      _token2 = insert(:auth_token, user: user)

      assert {2, nil} = Accounts.delete_all_user_tokens(user.id)
      assert Accounts.list_user_tokens(user.id) == []
    end

    test "doesn't affect other users' tokens" do
      user1 = insert(:user)
      user2 = insert(:user)
      _token1 = insert(:auth_token, user: user1)
      _token2 = insert(:auth_token, user: user2)

      assert {1, nil} = Accounts.delete_all_user_tokens(user1.id)
      assert length(Accounts.list_user_tokens(user2.id)) == 1
    end
  end

  describe "delete_expired_tokens/0" do
    test "deletes expired tokens" do
      user = insert(:user)
      _active = insert(:auth_token, user: user)

      _expired1 =
        insert(:auth_token,
          user: user,
          expires_at:
            DateTime.utc_now() |> DateTime.add(-100, :second) |> DateTime.truncate(:second)
        )

      _expired2 =
        insert(:auth_token,
          user: user,
          expires_at:
            DateTime.utc_now() |> DateTime.add(-200, :second) |> DateTime.truncate(:second)
        )

      assert {2, nil} = Accounts.delete_expired_tokens()
      assert length(Accounts.list_user_tokens(user.id)) == 1
    end
  end

  describe "revoke_all_user_tokens/2" do
    test "revokes all user tokens and adds them to blacklist" do
      user = insert(:user)
      token1 = insert(:auth_token, user: user)
      token2 = insert(:auth_token, user: user)

      assert {:ok, _} = Accounts.revoke_all_user_tokens(user.id, "test_revocation")

      # Tokens should be deleted
      assert Accounts.list_user_tokens(user.id) == []

      # Tokens should be blacklisted
      assert Accounts.token_blacklisted?(token1.token_hash)
      assert Accounts.token_blacklisted?(token2.token_hash)
    end
  end

  describe "blacklist_token/4" do
    test "adds token to blacklist" do
      user = insert(:user)
      token_hash = "test_hash_123"
      expires_at = DateTime.utc_now() |> DateTime.add(900, :second)

      assert {:ok, %TokenBlacklist{}} =
               Accounts.blacklist_token(token_hash, user.id, "logout", expires_at)

      assert Accounts.token_blacklisted?(token_hash)
    end

    test "handles duplicate blacklist entries gracefully" do
      user = insert(:user)
      token_hash = "test_hash_456"
      expires_at = DateTime.utc_now() |> DateTime.add(900, :second)

      assert {:ok, _} = Accounts.blacklist_token(token_hash, user.id, "logout", expires_at)
      assert {:ok, _} = Accounts.blacklist_token(token_hash, user.id, "logout", expires_at)
    end
  end

  describe "token_blacklisted?/1" do
    test "returns true for blacklisted token" do
      user = insert(:user)
      blacklist_entry = insert(:token_blacklist, user: user)

      assert Accounts.token_blacklisted?(blacklist_entry.token_hash)
    end

    test "returns false for non-blacklisted token" do
      refute Accounts.token_blacklisted?("non_existent_hash")
    end
  end

  describe "clean_expired_blacklist/0" do
    test "removes expired blacklist entries" do
      user = insert(:user)

      _active =
        insert(:token_blacklist,
          user: user,
          expires_at:
            DateTime.utc_now() |> DateTime.add(900, :second) |> DateTime.truncate(:second)
        )

      expired1 =
        insert(:token_blacklist,
          user: user,
          expires_at:
            DateTime.utc_now() |> DateTime.add(-100, :second) |> DateTime.truncate(:second)
        )

      expired2 =
        insert(:token_blacklist,
          user: user,
          expires_at:
            DateTime.utc_now() |> DateTime.add(-200, :second) |> DateTime.truncate(:second)
        )

      assert {2, nil} = Accounts.clean_expired_blacklist()

      refute Accounts.token_blacklisted?(expired1.token_hash)
      refute Accounts.token_blacklisted?(expired2.token_hash)
    end
  end

  describe "verify_token/2" do
    test "returns user and token for valid access token" do
      user = insert(:user)
      token_string = "valid_token_string"
      token_hash = AuthToken.hash_token(token_string)

      insert(:auth_token,
        user: user,
        token_hash: token_hash,
        token_type: "access",
        expires_at: DateTime.utc_now() |> DateTime.add(900, :second) |> DateTime.truncate(:second)
      )

      assert {:ok, returned_user, auth_token} = Accounts.verify_token(token_string, "access")
      assert returned_user.id == user.id
      assert auth_token.token_hash == token_hash
    end

    test "returns error for blacklisted token" do
      user = insert(:user)
      token_string = "blacklisted_token"
      token_hash = AuthToken.hash_token(token_string)

      insert(:auth_token,
        user: user,
        token_hash: token_hash,
        token_type: "access",
        expires_at: DateTime.utc_now() |> DateTime.add(900, :second) |> DateTime.truncate(:second)
      )

      insert(:token_blacklist,
        user: user,
        token_hash: token_hash,
        expires_at: DateTime.utc_now() |> DateTime.add(900, :second) |> DateTime.truncate(:second)
      )

      assert {:error, :token_blacklisted} = Accounts.verify_token(token_string, "access")
    end

    test "returns error for non-existent token" do
      assert {:error, :token_not_found} = Accounts.verify_token("nonexistent", "access")
    end

    test "returns error for expired token" do
      user = insert(:user)
      token_string = "expired_token"
      token_hash = AuthToken.hash_token(token_string)

      insert(:auth_token,
        user: user,
        token_hash: token_hash,
        token_type: "access",
        expires_at: DateTime.utc_now() |> DateTime.add(-1, :second) |> DateTime.truncate(:second)
      )

      assert {:error, :token_expired} = Accounts.verify_token(token_string, "access")
    end

    test "returns error for wrong token type" do
      user = insert(:user)
      token_string = "refresh_token"
      token_hash = AuthToken.hash_token(token_string)

      insert(:auth_token,
        user: user,
        token_hash: token_hash,
        token_type: "refresh",
        expires_at:
          DateTime.utc_now() |> DateTime.add(2_592_000, :second) |> DateTime.truncate(:second)
      )

      # Type mismatch should return invalid_token error
      result = Accounts.verify_token(token_string, "access")
      assert match?({:error, _}, result)
    end

    test "updates last_used_at on successful verification" do
      user = insert(:user)
      token_string = "valid_token"
      token_hash = AuthToken.hash_token(token_string)

      token =
        insert(:auth_token,
          user: user,
          token_hash: token_hash,
          token_type: "access",
          expires_at:
            DateTime.utc_now() |> DateTime.add(900, :second) |> DateTime.truncate(:second),
          last_used_at: nil
        )

      assert {:ok, _user, _auth_token} = Accounts.verify_token(token_string, "access")

      updated_token = Accounts.get_auth_token_by_hash(token_hash)
      assert updated_token.last_used_at != nil
      assert updated_token.last_used_at != token.last_used_at
    end
  end

  # Helper functions for test factories
  defp insert(:user) do
    Shadowfax.Repo.insert!(%Shadowfax.Accounts.User{
      username: "user_#{System.unique_integer([:positive])}",
      email: "user_#{System.unique_integer([:positive])}@example.com",
      hashed_password: Bcrypt.hash_pwd_salt("password123"),
      first_name: "Test",
      last_name: "User"
    })
  end

  defp insert(:auth_token, opts) do
    user = Keyword.get(opts, :user)

    Shadowfax.Repo.insert!(%AuthToken{
      user_id: user.id,
      token_hash: Keyword.get(opts, :token_hash, "hash_#{System.unique_integer([:positive])}"),
      token_type: Keyword.get(opts, :token_type, "access"),
      token_version: Keyword.get(opts, :token_version, 1),
      expires_at:
        Keyword.get(
          opts,
          :expires_at,
          DateTime.utc_now() |> DateTime.add(900, :second) |> DateTime.truncate(:second)
        ),
      last_used_at: Keyword.get(opts, :last_used_at, nil),
      device_info: Keyword.get(opts, :device_info, %{}),
      ip_address: Keyword.get(opts, :ip_address, "127.0.0.1")
    })
  end

  defp insert(:token_blacklist, opts) do
    user = Keyword.get(opts, :user)

    Shadowfax.Repo.insert!(%TokenBlacklist{
      user_id: user.id,
      token_hash:
        Keyword.get(opts, :token_hash, "blacklist_hash_#{System.unique_integer([:positive])}"),
      reason: Keyword.get(opts, :reason, "test"),
      expires_at:
        Keyword.get(
          opts,
          :expires_at,
          DateTime.utc_now() |> DateTime.add(900, :second) |> DateTime.truncate(:second)
        )
    })
  end
end
