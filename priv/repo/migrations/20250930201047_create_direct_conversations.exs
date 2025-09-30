defmodule Shadowfax.Repo.Migrations.CreateDirectConversations do
  use Ecto.Migration

  def change do
    create table(:direct_conversations) do
      add :user1_id, references(:users, on_delete: :delete_all), null: false
      add :user2_id, references(:users, on_delete: :delete_all), null: false
      add :last_message_at, :naive_datetime
      add :is_archived_by_user1, :boolean, default: false, null: false
      add :is_archived_by_user2, :boolean, default: false, null: false

      timestamps()
    end

    create unique_index(:direct_conversations, [:user1_id, :user2_id])
    create index(:direct_conversations, [:user1_id])
    create index(:direct_conversations, [:user2_id])
    create index(:direct_conversations, [:last_message_at])

    # Ensure user1_id < user2_id to avoid duplicate conversations
    create constraint(:direct_conversations, :user1_less_than_user2, check: "user1_id < user2_id")
  end
end
