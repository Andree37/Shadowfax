defmodule Shadowfax.Repo.Migrations.RemovePresenceFieldsFromUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      remove :is_online
      remove :last_seen_at
    end
  end
end
