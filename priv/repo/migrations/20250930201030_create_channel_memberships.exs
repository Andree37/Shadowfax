defmodule Shadowfax.Repo.Migrations.CreateChannelMemberships do
  use Ecto.Migration

  def change do
    create table(:channel_memberships) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :channel_id, references(:channels, on_delete: :delete_all), null: false
      add :role, :string, default: "member", null: false
      add :joined_at, :naive_datetime, null: false
      add :last_read_at, :naive_datetime
      add :is_muted, :boolean, default: false, null: false
      add :notification_preference, :string, default: "all", null: false

      timestamps()
    end

    create unique_index(:channel_memberships, [:user_id, :channel_id])
    create index(:channel_memberships, [:user_id])
    create index(:channel_memberships, [:channel_id])
    create index(:channel_memberships, [:role])
  end
end
