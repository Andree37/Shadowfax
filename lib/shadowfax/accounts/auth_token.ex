defmodule Shadowfax.Accounts.AuthToken do
  use Ecto.Schema
  import Ecto.Changeset

  alias Shadowfax.Accounts.User

  @token_types ["access", "refresh"]
  # 15 minutes
  @access_token_ttl 60 * 15
  # 30 days
  @refresh_token_ttl 60 * 60 * 24 * 30

  schema "auth_tokens" do
    field :token_hash, :string
    field :token_type, :string, default: "access"
    field :token_version, :integer, default: 1
    field :expires_at, :utc_datetime
    field :last_used_at, :utc_datetime
    field :device_info, :map
    field :ip_address, :string

    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(auth_token, attrs) do
    auth_token
    |> cast(attrs, [
      :user_id,
      :token_hash,
      :token_type,
      :token_version,
      :expires_at,
      :last_used_at,
      :device_info,
      :ip_address
    ])
    |> validate_required([:user_id, :token_hash, :token_type, :token_version, :expires_at])
    |> validate_inclusion(:token_type, @token_types)
    |> validate_number(:token_version, greater_than: 0)
    |> unique_constraint(:token_hash)
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Returns the TTL in seconds for the given token type
  """
  def get_ttl("access"), do: @access_token_ttl
  def get_ttl("refresh"), do: @refresh_token_ttl
  def get_ttl(_), do: @access_token_ttl

  @doc """
  Calculates the expiration datetime for a given token type
  """
  def calculate_expiration(token_type) do
    DateTime.utc_now()
    |> DateTime.add(get_ttl(token_type), :second)
  end

  @doc """
  Checks if a token is expired
  """
  def expired?(%__MODULE__{expires_at: expires_at}) do
    DateTime.compare(DateTime.utc_now(), expires_at) == :gt
  end

  @doc """
  Checks if a token is still valid (not expired)
  """
  def valid?(%__MODULE__{} = token) do
    not expired?(token)
  end

  @doc """
  Hashes a token string for storage
  """
  def hash_token(token) do
    :crypto.hash(:sha256, token)
    |> Base.encode16(case: :lower)
  end
end
