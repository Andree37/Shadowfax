defmodule Shadowfax.Repo.Migrations.CreateAuthTokens do
  use Ecto.Migration

  def change do
    create table(:auth_tokens) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :token_hash, :string, null: false
      add :token_type, :string, null: false, default: "access"
      add :token_version, :integer, null: false, default: 1
      add :expires_at, :utc_datetime, null: false
      add :last_used_at, :utc_datetime
      add :device_info, :map
      add :ip_address, :string

      timestamps(type: :utc_datetime)
    end

    create index(:auth_tokens, [:user_id])
    create unique_index(:auth_tokens, [:token_hash])
    create index(:auth_tokens, [:expires_at])
    create index(:auth_tokens, [:token_type])

    create table(:token_blacklist) do
      add :token_hash, :string, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :reason, :string
      add :expires_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:token_blacklist, [:token_hash])
    create index(:token_blacklist, [:expires_at])
    create index(:token_blacklist, [:user_id])
  end
end
