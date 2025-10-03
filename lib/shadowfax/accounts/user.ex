defmodule Shadowfax.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Shadowfax.Chat.{Channel, ChannelMembership, Message, DirectConversation}

  schema "users" do
    field :username, :string
    field :email, :string
    field :hashed_password, :string
    field :password, :string, virtual: true, redact: true
    field :first_name, :string
    field :last_name, :string
    field :avatar_url, :string
    field :status, :string, default: "offline"
    field :is_online, :boolean, default: false
    field :last_seen_at, :naive_datetime

    # Associations
    has_many :created_channels, Channel, foreign_key: :created_by_id
    has_many :channel_memberships, ChannelMembership
    has_many :channels, through: [:channel_memberships, :channel]
    has_many :messages, Message

    has_many :initiated_conversations, DirectConversation, foreign_key: :user1_id
    has_many :received_conversations, DirectConversation, foreign_key: :user2_id

    timestamps()
  end

  @doc """
  A user changeset for registration.
  """
  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:username, :email, :password, :first_name, :last_name, :avatar_url])
    |> validate_email(opts)
    |> validate_password(opts)
    |> validate_username()
  end

  @doc """
  A user changeset for profile updates.
  """
  def profile_changeset(user, attrs) do
    user
    |> cast(attrs, [:first_name, :last_name, :avatar_url, :status])
    |> validate_status()
  end

  @doc """
  A user changeset for updating online status.
  """
  def status_changeset(user, attrs) do
    user
    |> cast(attrs, [:is_online, :last_seen_at, :status])
    |> validate_status()
  end

  defp validate_email(changeset, opts) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> maybe_validate_unique_email(opts)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 8, max: 72)
    |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/,
      message: "at least one digit or punctuation character"
    )
    |> maybe_hash_password(opts)
  end

  defp validate_username(changeset) do
    changeset
    |> validate_required([:username])
    |> validate_length(:username, min: 3, max: 30)
    |> validate_format(:username, ~r/^[a-zA-Z0-9_-]+$/,
      message: "only letters, numbers, underscores, and hyphens allowed"
    )
    |> unsafe_validate_unique(:username, Shadowfax.Repo)
    |> unique_constraint(:username)
  end

  defp validate_status(changeset) do
    valid_statuses = ["online", "away", "busy", "offline"]
    validate_inclusion(changeset, :status, valid_statuses)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  defp maybe_validate_unique_email(changeset, opts) do
    if Keyword.get(opts, :validate_email, true) do
      changeset
      |> unsafe_validate_unique(:email, Shadowfax.Repo)
      |> unique_constraint(:email)
    else
      changeset
    end
  end

  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Bcrypt.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%__MODULE__{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end

  @doc """
  Returns the user's full name.
  """
  def full_name(%__MODULE__{first_name: first_name, last_name: last_name}) do
    case {first_name, last_name} do
      {nil, nil} -> nil
      {first, nil} -> first
      {nil, last} -> last
      {first, last} -> "#{first} #{last}"
    end
  end

  @doc """
  Returns the user's display name (full name or username).
  """
  def display_name(%__MODULE__{} = user) do
    full_name(user) || user.username
  end

  @doc """
  Returns all direct conversations for a user.
  """
  def direct_conversations_query(%__MODULE__{id: user_id}) do
    from(dc in DirectConversation,
      where: dc.user1_id == ^user_id or dc.user2_id == ^user_id
    )
  end

  @doc """
  Checks if the user is online.
  """
  def online?(%__MODULE__{is_online: is_online}), do: is_online
end
