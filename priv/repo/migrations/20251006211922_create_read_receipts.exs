defmodule Shadowfax.Repo.Migrations.CreateReadReceipts do
  use Ecto.Migration

  def change do
    create table(:read_receipts) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :channel_id, references(:channels, on_delete: :delete_all)
      add :direct_conversation_id, references(:direct_conversations, on_delete: :delete_all)
      add :last_read_message_id, references(:messages, on_delete: :nilify_all), null: false

      timestamps()
    end

    create unique_index(:read_receipts, [:user_id, :channel_id],
             where: "channel_id IS NOT NULL",
             name: :read_receipts_user_channel_index
           )

    create unique_index(:read_receipts, [:user_id, :direct_conversation_id],
             where: "direct_conversation_id IS NOT NULL",
             name: :read_receipts_user_conversation_index
           )

    create index(:read_receipts, [:user_id])
    create index(:read_receipts, [:channel_id])
    create index(:read_receipts, [:direct_conversation_id])
  end
end
