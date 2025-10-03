defmodule Shadowfax.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Shadowfax.Repo

  alias Shadowfax.Accounts.User
  alias Shadowfax.Accounts.AuthToken
  alias Shadowfax.Accounts.TokenBlacklist

  @doc """
  Returns the list of users.

  ## Examples

      iex> list_users()
      [%User{}, ...]

  """
  def list_users do
    Repo.all(User)
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by username.

  ## Examples

      iex> get_user_by_username("john_doe")
      %User{}

      iex> get_user_by_username("unknown")
      nil

  """
  def get_user_by_username(username) when is_binary(username) do
    Repo.get_by(User, username: username)
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = get_user_by_email(email)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Creates a user.

  ## Examples

      iex> create_user(%{field: value})
      {:ok, %User{}}

      iex> create_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user.

  ## Examples

      iex> update_user(user, %{field: new_value})
      {:ok, %User{}}

      iex> update_user(user, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.profile_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a user.

  ## Examples

      iex> delete_user(user)
      {:ok, %User{}}

      iex> delete_user(user)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user(%User{} = user, attrs \\ %{}) do
    User.profile_changeset(user, attrs)
  end

  @doc """
  Searches for users by username or email.

  ## Examples

      iex> search_users("john")
      [%User{username: "john_doe"}, ...]

  """
  def search_users(query) when is_binary(query) do
    search_term = "%#{query}%"

    from(u in User,
      where: ilike(u.username, ^search_term) or ilike(u.email, ^search_term),
      order_by: u.username,
      limit: 10
    )
    |> Repo.all()
  end

  @doc """
  Gets users by a list of IDs.

  ## Examples

      iex> get_users_by_ids([1, 2, 3])
      [%User{}, %User{}, %User{}]

  """
  def get_users_by_ids(ids) when is_list(ids) do
    from(u in User, where: u.id in ^ids)
    |> Repo.all()
  end

  @doc """
  Returns a changeset for user registration.

  ## Examples

      iex> registration_changeset(%{username: "john", email: "john@example.com"})
      %Ecto.Changeset{}

  """
  def registration_changeset(attrs \\ %{}) do
    User.registration_changeset(%User{}, attrs)
  end

  @doc """
  Checks if a username is available.

  ## Examples

      iex> username_available?("john_doe")
      false

      iex> username_available?("available_username")
      true

  """
  def username_available?(username) when is_binary(username) do
    not Repo.exists?(from u in User, where: u.username == ^username)
  end

  @doc """
  Checks if an email is available.

  ## Examples

      iex> email_available?("taken@example.com")
      false

      iex> email_available?("available@example.com")
      true

  """
  def email_available?(email) when is_binary(email) do
    not Repo.exists?(from u in User, where: u.email == ^email)
  end

  @doc """
  Gets user statistics.

  ## Examples

      iex> get_user_stats()
      %{total_users: 150, new_users_today: 5}

  """
  def get_user_stats do
    today = Date.utc_today()
    start_of_day = NaiveDateTime.new!(today, ~T[00:00:00])

    total_users = Repo.aggregate(User, :count)

    new_users_today =
      Repo.aggregate(from(u in User, where: u.inserted_at >= ^start_of_day), :count)

    %{
      total_users: total_users,
      new_users_today: new_users_today
    }
  end

  # Token Management Functions

  @doc """
  Creates an auth token for a user.

  ## Examples

      iex> create_auth_token(%{user_id: 1, token_hash: "...", token_type: "access"})
      {:ok, %AuthToken{}}

  """
  def create_auth_token(attrs \\ %{}) do
    %AuthToken{}
    |> AuthToken.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets an auth token by its hash.

  ## Examples

      iex> get_auth_token_by_hash("hash123")
      %AuthToken{}

      iex> get_auth_token_by_hash("invalid")
      nil

  """
  def get_auth_token_by_hash(token_hash) when is_binary(token_hash) do
    Repo.get_by(AuthToken, token_hash: token_hash)
    |> Repo.preload(:user)
  end

  @doc """
  Gets all active tokens for a user.

  ## Examples

      iex> list_user_tokens(1)
      [%AuthToken{}, ...]

  """
  def list_user_tokens(user_id) do
    now = DateTime.utc_now()

    from(t in AuthToken,
      where: t.user_id == ^user_id and t.expires_at > ^now,
      order_by: [desc: t.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Updates an auth token's last used timestamp.

  ## Examples

      iex> update_token_last_used(token)
      {:ok, %AuthToken{}}

  """
  def update_token_last_used(%AuthToken{} = token) do
    token
    |> Ecto.Changeset.change(%{last_used_at: DateTime.utc_now() |> DateTime.truncate(:second)})
    |> Repo.update()
  end

  @doc """
  Deletes an auth token.

  ## Examples

      iex> delete_auth_token(token)
      {:ok, %AuthToken{}}

  """
  def delete_auth_token(%AuthToken{} = token) do
    Repo.delete(token)
  end

  @doc """
  Deletes all tokens for a user.

  ## Examples

      iex> delete_all_user_tokens(1)
      {5, nil}

  """
  def delete_all_user_tokens(user_id) do
    from(t in AuthToken, where: t.user_id == ^user_id)
    |> Repo.delete_all()
  end

  @doc """
  Deletes expired tokens. Should be run periodically.

  ## Examples

      iex> delete_expired_tokens()
      {10, nil}

  """
  def delete_expired_tokens do
    now = DateTime.utc_now()

    from(t in AuthToken, where: t.expires_at < ^now)
    |> Repo.delete_all()
  end

  @doc """
  Revokes all tokens for a user by incrementing their token version.
  This invalidates all existing tokens without deleting them.

  ## Examples

      iex> revoke_all_user_tokens(1, "password_changed")
      {:ok, 5}

  """
  def revoke_all_user_tokens(user_id, reason \\ "manual_revocation") do
    tokens = list_user_tokens(user_id)

    Repo.transaction(fn ->
      Enum.each(tokens, fn token ->
        blacklist_token(token.token_hash, user_id, reason, token.expires_at)
      end)

      delete_all_user_tokens(user_id)
    end)
  end

  # Token Blacklist Functions

  @doc """
  Adds a token to the blacklist.

  ## Examples

      iex> blacklist_token("hash123", 1, "logout", ~U[2025-01-01 00:00:00Z])
      {:ok, %TokenBlacklist{}}

  """
  def blacklist_token(token_hash, user_id, reason, expires_at) do
    %TokenBlacklist{}
    |> TokenBlacklist.changeset(%{
      token_hash: token_hash,
      user_id: user_id,
      reason: reason,
      expires_at: expires_at
    })
    |> Repo.insert(on_conflict: :nothing)
  end

  @doc """
  Checks if a token is blacklisted.

  ## Examples

      iex> token_blacklisted?("hash123")
      true

      iex> token_blacklisted?("valid_hash")
      false

  """
  def token_blacklisted?(token_hash) when is_binary(token_hash) do
    Repo.exists?(from b in TokenBlacklist, where: b.token_hash == ^token_hash)
  end

  @doc """
  Deletes expired blacklist entries. Should be run periodically.

  ## Examples

      iex> clean_expired_blacklist()
      {15, nil}

  """
  def clean_expired_blacklist do
    now = DateTime.utc_now()

    from(b in TokenBlacklist, where: b.expires_at < ^now)
    |> Repo.delete_all()
  end

  @doc """
  Verifies a token and returns the associated user if valid.

  ## Examples

      iex> verify_token("valid_token", "access")
      {:ok, %User{}, %AuthToken{}}

      iex> verify_token("invalid_token", "access")
      {:error, :invalid_token}

  """
  def verify_token(token_string, expected_type \\ "access") do
    token_hash = AuthToken.hash_token(token_string)

    with false <- token_blacklisted?(token_hash),
         %AuthToken{} = token <- get_auth_token_by_hash(token_hash),
         :ok <- check_token_type(token.token_type, expected_type),
         true <- AuthToken.valid?(token) do
      update_token_last_used(token)
      {:ok, token.user, token}
    else
      true -> {:error, :token_blacklisted}
      nil -> {:error, :token_not_found}
      {:error, reason} -> {:error, reason}
      false -> {:error, :token_expired}
      _ -> {:error, :invalid_token}
    end
  end

  defp check_token_type(actual_type, expected_type) do
    if actual_type == expected_type do
      :ok
    else
      {:error, :invalid_token_type}
    end
  end
end
