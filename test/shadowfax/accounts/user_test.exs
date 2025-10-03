defmodule Shadowfax.Accounts.UserTest do
  use Shadowfax.DataCase, async: true

  alias Shadowfax.Accounts.User

  describe "password hashing with Bcrypt" do
    test "hashes password on registration changeset" do
      changeset =
        User.registration_changeset(%User{}, %{
          username: "testuser",
          email: "test@example.com",
          password: "SecurePass123!",
          first_name: "Test",
          last_name: "User"
        })

      assert changeset.valid?
      hashed_password = Ecto.Changeset.get_change(changeset, :hashed_password)
      assert hashed_password != nil
      assert hashed_password != "SecurePass123!"
      # Bcrypt hashes start with $2b$
      assert String.starts_with?(hashed_password, "$2b$")
    end

    test "does not store plain text password" do
      changeset =
        User.registration_changeset(%User{}, %{
          username: "testuser",
          email: "test@example.com",
          password: "SecurePass123!",
          first_name: "Test",
          last_name: "User"
        })

      # Password should be deleted from changeset
      assert Ecto.Changeset.get_change(changeset, :password) == nil
    end

    test "generates different hashes for same password" do
      attrs = %{
        username: "testuser",
        email: "test@example.com",
        password: "SecurePass123!",
        first_name: "Test",
        last_name: "User"
      }

      changeset1 = User.registration_changeset(%User{}, attrs)
      changeset2 = User.registration_changeset(%User{}, attrs)

      hash1 = Ecto.Changeset.get_change(changeset1, :hashed_password)
      hash2 = Ecto.Changeset.get_change(changeset2, :hashed_password)

      # Bcrypt generates unique salts, so hashes should differ
      assert hash1 != hash2
    end

    test "does not hash password when hash_password option is false" do
      changeset =
        User.registration_changeset(
          %User{},
          %{
            username: "testuser",
            email: "test@example.com",
            password: "SecurePass123!",
            first_name: "Test",
            last_name: "User"
          },
          hash_password: false
        )

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :hashed_password) == nil
      assert Ecto.Changeset.get_change(changeset, :password) == "SecurePass123!"
    end
  end

  describe "valid_password?/2" do
    test "returns true for correct password" do
      password = "CorrectPass123!"

      user = %User{
        hashed_password: Bcrypt.hash_pwd_salt(password)
      }

      assert User.valid_password?(user, password) == true
    end

    test "returns false for incorrect password" do
      user = %User{
        hashed_password: Bcrypt.hash_pwd_salt("CorrectPass123!")
      }

      assert User.valid_password?(user, "WrongPassword") == false
    end

    test "returns false when user has no hashed_password" do
      user = %User{hashed_password: nil}

      assert User.valid_password?(user, "AnyPassword") == false
    end

    test "returns false when password is empty" do
      user = %User{
        hashed_password: Bcrypt.hash_pwd_salt("SomePassword123!")
      }

      assert User.valid_password?(user, "") == false
    end

    test "prevents timing attacks by calling Bcrypt.no_user_verify when user is nil" do
      # This test verifies the function doesn't crash and returns false
      # The actual timing attack prevention is handled by Bcrypt.no_user_verify/0
      assert User.valid_password?(nil, "password") == false
    end

    test "verifies password against legacy Base64 hashes fails" do
      # Old Base64 hash (should no longer work)
      user = %User{
        hashed_password: Base.encode64("OldPassword123!" <> "salt")
      }

      # Should return false since Bcrypt can't verify Base64 hashes
      assert User.valid_password?(user, "OldPassword123!") == false
    end
  end

  describe "password validation" do
    test "requires minimum 8 characters" do
      changeset =
        User.registration_changeset(%User{}, %{
          username: "user",
          email: "test@example.com",
          password: "Short1!"
        })

      assert %{password: ["should be at least 8 character(s)"]} = errors_on(changeset)
    end

    test "requires at least one lowercase character" do
      changeset =
        User.registration_changeset(%User{}, %{
          username: "user",
          email: "test@example.com",
          password: "NOLOWERCASE123!"
        })

      assert %{password: ["at least one lower case character"]} = errors_on(changeset)
    end

    test "requires at least one uppercase character" do
      changeset =
        User.registration_changeset(%User{}, %{
          username: "user",
          email: "test@example.com",
          password: "nouppercase123!"
        })

      assert %{password: ["at least one upper case character"]} = errors_on(changeset)
    end

    test "requires at least one digit or punctuation" do
      changeset =
        User.registration_changeset(%User{}, %{
          username: "user",
          email: "test@example.com",
          password: "NoDigitsOrPunctuation"
        })

      assert %{password: ["at least one digit or punctuation character"]} = errors_on(changeset)
    end
  end
end
