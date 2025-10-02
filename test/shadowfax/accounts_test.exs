defmodule Shadowfax.AccountsTest do
  use Shadowfax.DataCase, async: true

  alias Shadowfax.Accounts
  alias Shadowfax.Repo

  setup do
    # Clear the database before each test
    Repo.delete_all(Shadowfax.Accounts.User)
    :ok
  end

  describe "create_user/1" do
    test "creates a user with valid attributes" do
      attrs = %{
        username: "newuser",
        email: "new@example.com",
        password: "ValidPass1!",
        first_name: "New",
        last_name: "User"
      }

      assert {:ok, user} = Accounts.create_user(attrs)
      assert user.username == "newuser"
      assert user.email == "new@example.com"
      assert user.first_name == "New"
      assert user.last_name == "User"
      assert user.hashed_password != nil
      assert user.hashed_password != attrs.password
    end

    test "requires username, email, and password" do
      assert {:error, changeset} = Accounts.create_user(%{})
      assert %{username: _, email: _, password: _} = errors_on(changeset)
    end

    test "validates username uniqueness" do
      attrs = %{username: "unique", email: "first@example.com", password: "Pass1234!"}
      assert {:ok, _user} = Accounts.create_user(attrs)

      attrs2 = %{username: "unique", email: "second@example.com", password: "Pass1234!"}
      assert {:error, changeset} = Accounts.create_user(attrs2)
      assert %{username: ["has already been taken"]} = errors_on(changeset)
    end

    test "validates email uniqueness" do
      attrs = %{username: "user1", email: "same@example.com", password: "Pass1234!"}
      assert {:ok, _user} = Accounts.create_user(attrs)

      attrs2 = %{username: "user2", email: "same@example.com", password: "Pass1234!"}
      assert {:error, changeset} = Accounts.create_user(attrs2)
      assert %{email: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "get_user_by_email/1" do
    test "returns user when email exists" do
      {:ok, user} =
        Accounts.create_user(%{
          username: "findme",
          email: "find@example.com",
          password: "Pass1234!"
        })

      found = Accounts.get_user_by_email("find@example.com")
      assert found.id == user.id
    end

    test "returns nil when email does not exist" do
      assert Accounts.get_user_by_email("nonexistent@example.com") == nil
    end
  end

  describe "get_user_by_username/1" do
    test "returns user when username exists" do
      {:ok, user} =
        Accounts.create_user(%{
          username: "findme",
          email: "find@example.com",
          password: "Pass1234!"
        })

      found = Accounts.get_user_by_username("findme")
      assert found.id == user.id
    end

    test "returns nil when username does not exist" do
      assert Accounts.get_user_by_username("nonexistent") == nil
    end
  end

  describe "get_user_by_email_and_password/2" do
    test "returns user with correct credentials" do
      {:ok, user} =
        Accounts.create_user(%{
          username: "authuser",
          email: "auth@example.com",
          password: "CorrectPass1!"
        })

      found = Accounts.get_user_by_email_and_password("auth@example.com", "CorrectPass1!")
      assert found.id == user.id
    end

    test "returns nil with incorrect password" do
      {:ok, _user} =
        Accounts.create_user(%{
          username: "authuser",
          email: "auth@example.com",
          password: "CorrectPass1!"
        })

      found = Accounts.get_user_by_email_and_password("auth@example.com", "WrongPass1!")
      assert found == nil
    end

    test "returns nil with nonexistent email" do
      found = Accounts.get_user_by_email_and_password("nobody@example.com", "AnyPass1!")
      assert found == nil
    end
  end

  describe "update_user/2" do
    test "updates user profile information" do
      {:ok, user} =
        Accounts.create_user(%{
          username: "updateme",
          email: "update@example.com",
          password: "Pass1234!"
        })

      assert {:ok, updated} =
               Accounts.update_user(user, %{
                 first_name: "Updated",
                 last_name: "Name",
                 status: "away"
               })

      assert updated.first_name == "Updated"
      assert updated.last_name == "Name"
      assert updated.status == "away"
    end

    test "validates status values" do
      {:ok, user} =
        Accounts.create_user(%{
          username: "statustest",
          email: "status@example.com",
          password: "Pass1234!"
        })

      assert {:error, changeset} = Accounts.update_user(user, %{status: "invalid"})
      assert %{status: _} = errors_on(changeset)
    end
  end

  describe "update_user_status/2" do
    test "updates user online status and last_seen_at" do
      {:ok, user} =
        Accounts.create_user(%{
          username: "onlinetest",
          email: "online@example.com",
          password: "Pass1234!"
        })

      assert user.is_online == false
      assert user.last_seen_at == nil

      assert {:ok, updated} =
               Accounts.update_user_status(user, %{
                 is_online: true,
                 status: "online"
               })

      assert updated.is_online == true
      assert updated.status == "online"
      assert updated.last_seen_at != nil
    end
  end

  describe "set_user_online/1 and set_user_offline/1" do
    test "sets user online" do
      {:ok, user} =
        Accounts.create_user(%{
          username: "online",
          email: "online@example.com",
          password: "Pass1234!"
        })

      {:ok, online_user} = Accounts.set_user_online(user)
      assert online_user.is_online == true
      assert online_user.status == "online"
    end

    test "sets user offline" do
      {:ok, user} =
        Accounts.create_user(%{
          username: "offline",
          email: "offline@example.com",
          password: "Pass1234!"
        })

      {:ok, online_user} = Accounts.set_user_online(user)
      {:ok, offline_user} = Accounts.set_user_offline(online_user)

      assert offline_user.is_online == false
      assert offline_user.status == "offline"
    end
  end

  describe "list_online_users/0" do
    test "returns only online users" do
      {:ok, user1} =
        Accounts.create_user(%{
          username: "online1",
          email: "online1@example.com",
          password: "Pass1234!"
        })

      {:ok, user2} =
        Accounts.create_user(%{
          username: "online2",
          email: "online2@example.com",
          password: "Pass1234!"
        })

      {:ok, _user3} =
        Accounts.create_user(%{
          username: "offline",
          email: "offline@example.com",
          password: "Pass1234!"
        })

      Accounts.set_user_online(user1)
      Accounts.set_user_online(user2)

      online_users = Accounts.list_online_users()
      assert length(online_users) == 2
      assert Enum.all?(online_users, fn u -> u.is_online == true end)
    end
  end

  describe "search_users/1" do
    test "finds users by username pattern" do
      {:ok, _user1} =
        Accounts.create_user(%{
          username: "alice_wonder",
          email: "alice@example.com",
          password: "Pass1234!"
        })

      {:ok, _user2} =
        Accounts.create_user(%{
          username: "alice_smith",
          email: "alice2@example.com",
          password: "Pass1234!"
        })

      {:ok, _user3} =
        Accounts.create_user(%{
          username: "bob",
          email: "bob@example.com",
          password: "Pass1234!"
        })

      results = Accounts.search_users("alice")
      assert length(results) == 2
    end

    test "finds users by email pattern" do
      {:ok, _user} =
        Accounts.create_user(%{
          username: "testuser",
          email: "unique@example.com",
          password: "Pass1234!"
        })

      results = Accounts.search_users("unique@")
      assert length(results) >= 1
    end

    test "limits results to 10" do
      for i <- 1..15 do
        Accounts.create_user(%{
          username: "user_#{i}",
          email: "user#{i}@example.com",
          password: "Pass1234!"
        })
      end

      results = Accounts.search_users("user")
      assert length(results) == 10
    end
  end

  describe "username_available?/1 and email_available?/1" do
    test "returns false for taken username" do
      {:ok, _user} =
        Accounts.create_user(%{
          username: "taken",
          email: "taken@example.com",
          password: "Pass1234!"
        })

      assert Accounts.username_available?("taken") == false
      assert Accounts.username_available?("available") == true
    end

    test "returns false for taken email" do
      {:ok, _user} =
        Accounts.create_user(%{
          username: "user",
          email: "taken@example.com",
          password: "Pass1234!"
        })

      assert Accounts.email_available?("taken@example.com") == false
      assert Accounts.email_available?("available@example.com") == true
    end
  end

  describe "get_user_stats/0" do
    test "returns user statistics" do
      {:ok, user1} =
        Accounts.create_user(%{
          username: "stats1",
          email: "stats1@example.com",
          password: "Pass1234!"
        })

      {:ok, _user2} =
        Accounts.create_user(%{
          username: "stats2",
          email: "stats2@example.com",
          password: "Pass1234!"
        })

      Accounts.set_user_online(user1)

      stats = Accounts.get_user_stats()
      assert stats.total_users == 2
      assert stats.online_users == 1
      assert is_integer(stats.new_users_today)
    end
  end

  describe "delete_user/1" do
    test "deletes a user" do
      {:ok, user} =
        Accounts.create_user(%{
          username: "deleteme",
          email: "delete@example.com",
          password: "Pass1234!"
        })

      assert {:ok, _deleted} = Accounts.delete_user(user)
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_user!(user.id) end
    end
  end
end
