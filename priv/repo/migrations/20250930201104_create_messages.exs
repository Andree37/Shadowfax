defmodule Shadowfax.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages) do
      add :content, :text, null: false
      add :message_type, :string, default: "text", null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :channel_id, references(:channels, on_delete: :delete_all)
      add :direct_conversation_id, references(:direct_conversations, on_delete: :delete_all)
      add :parent_message_id, references(:messages, on_delete: :nilify_all)
      add :edited_at, :naive_datetime
      add :is_deleted, :boolean, default: false, null: false
      add :metadata, :map
      add :attachments, {:array, :map}, default: []

      timestamps()
    end

    create index(:messages, [:user_id])
    create index(:messages, [:channel_id])
    create index(:messages, [:direct_conversation_id])
    create index(:messages, [:parent_message_id])
    create index(:messages, [:inserted_at])
    create index(:messages, [:message_type])

    # Ensure a message belongs to either a channel or a direct conversation, but not both
    create constraint(:messages, :belongs_to_channel_or_conversation,
             check: """
             (channel_id IS NOT NULL AND direct_conversation_id IS NULL) OR
             (channel_id IS NULL AND direct_conversation_id IS NOT NULL)
             """
           )
  end
end
