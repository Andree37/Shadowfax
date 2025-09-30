defmodule Shadowfax.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Shadowfax.Repo

  alias Shadowfax.Accounts.User

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
  Updates a user's online status and last seen time.

  ## Examples

      iex> update_user_status(user, %{is_online: true, status: "online"})
      {:ok, %User{}}

  """
  def update_user_status(%User{} = user, attrs) do
    attrs = Map.put(attrs, :last_seen_at, NaiveDateTime.utc_now())

    user
    |> User.status_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Sets a user as online.

  ## Examples

      iex> set_user_online(user)
      {:ok, %User{}}

  """
  def set_user_online(%User{} = user) do
    update_user_status(user, %{is_online: true, status: "online"})
  end

  @doc """
  Sets a user as offline.

  ## Examples

      iex> set_user_offline(user)
      {:ok, %User{}}

  """
  def set_user_offline(%User{} = user) do
    update_user_status(user, %{is_online: false, status: "offline"})
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
  Returns a list of users that are currently online.

  ## Examples

      iex> list_online_users()
      [%User{}, ...]

  """
  def list_online_users do
    from(u in User, where: u.is_online == true, order_by: u.username)
    |> Repo.all()
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
      %{total_users: 150, online_users: 23, new_users_today: 5}

  """
  def get_user_stats do
    today = Date.utc_today()
    start_of_day = NaiveDateTime.new!(today, ~T[00:00:00])

    total_users = Repo.aggregate(User, :count)
    online_users = Repo.aggregate(from(u in User, where: u.is_online == true), :count)

    new_users_today =
      Repo.aggregate(from(u in User, where: u.inserted_at >= ^start_of_day), :count)

    %{
      total_users: total_users,
      online_users: online_users,
      new_users_today: new_users_today
    }
  end
end
