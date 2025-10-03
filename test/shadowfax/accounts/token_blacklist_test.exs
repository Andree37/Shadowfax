defmodule Shadowfax.Accounts.TokenBlacklistTest do
  use Shadowfax.DataCase

  alias Shadowfax.Accounts.TokenBlacklist

  describe "changeset/2" do
    test "valid changeset with required fields" do
      attrs = %{
        token_hash: "abc123",
        user_id: 1,
        expires_at: DateTime.utc_now() |> DateTime.add(900, :second)
      }

      changeset = TokenBlacklist.changeset(%TokenBlacklist{}, attrs)
      assert changeset.valid?
    end

    test "requires token_hash" do
      attrs = %{
        user_id: 1,
        expires_at: DateTime.utc_now() |> DateTime.add(900, :second)
      }

      changeset = TokenBlacklist.changeset(%TokenBlacklist{}, attrs)
      assert %{token_hash: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires user_id" do
      attrs = %{
        token_hash: "abc123",
        expires_at: DateTime.utc_now() |> DateTime.add(900, :second)
      }

      changeset = TokenBlacklist.changeset(%TokenBlacklist{}, attrs)
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires expires_at" do
      attrs = %{
        token_hash: "abc123",
        user_id: 1
      }

      changeset = TokenBlacklist.changeset(%TokenBlacklist{}, attrs)
      assert %{expires_at: ["can't be blank"]} = errors_on(changeset)
    end

    test "accepts optional reason field" do
      attrs = %{
        token_hash: "abc123",
        user_id: 1,
        reason: "logout",
        expires_at: DateTime.utc_now() |> DateTime.add(900, :second)
      }

      changeset = TokenBlacklist.changeset(%TokenBlacklist{}, attrs)
      assert changeset.valid?
      assert changeset.changes.reason == "logout"
    end
  end
end
