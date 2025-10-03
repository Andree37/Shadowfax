defmodule Shadowfax.Accounts.TokenBlacklist do
  use Ecto.Schema
  import Ecto.Changeset

  alias Shadowfax.Accounts.User

  schema "token_blacklist" do
    field :token_hash, :string
    field :reason, :string
    field :expires_at, :utc_datetime

    belongs_to :user, User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc false
  def changeset(blacklist, attrs) do
    blacklist
    |> cast(attrs, [:token_hash, :user_id, :reason, :expires_at])
    |> validate_required([:token_hash, :user_id, :expires_at])
    |> unique_constraint(:token_hash)
    |> foreign_key_constraint(:user_id)
  end
end
