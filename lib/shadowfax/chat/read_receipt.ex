defmodule Shadowfax.Chat.ReadReceipt do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Shadowfax.Accounts.User
  alias Shadowfax.Chat.{Channel, DirectConversation, Message}

  schema "read_receipts" do
    field :last_read_message_id, :id

    # Associations
    belongs_to :user, User
    belongs_to :channel, Channel
    belongs_to :direct_conversation, DirectConversation

    timestamps()
  end

  @doc """
  A read receipt changeset for channel messages.
  """
  def channel_changeset(read_receipt, attrs) do
    read_receipt
    |> cast(attrs, [:user_id, :channel_id, :last_read_message_id])
    |> validate_required([:user_id, :channel_id, :last_read_message_id])
    |> validate_channel_message()
    |> unique_constraint([:user_id, :channel_id], name: :read_receipts_user_channel_index)
  end

  @doc """
  A read receipt changeset for direct messages.
  """
  def conversation_changeset(read_receipt, attrs) do
    read_receipt
    |> cast(attrs, [:user_id, :direct_conversation_id, :last_read_message_id])
    |> validate_required([:user_id, :direct_conversation_id, :last_read_message_id])
    |> validate_conversation_message()
    |> unique_constraint([:user_id, :direct_conversation_id],
      name: :read_receipts_user_conversation_index
    )
  end

  defp validate_channel_message(changeset) do
    # Ensure this is a channel read receipt (not a conversation)
    if get_field(changeset, :direct_conversation_id) do
      add_error(changeset, :channel_id, "cannot be set when direct_conversation_id is present")
    else
      changeset
    end
  end

  defp validate_conversation_message(changeset) do
    # Ensure this is a conversation read receipt (not a channel)
    if get_field(changeset, :channel_id) do
      add_error(changeset, :direct_conversation_id, "cannot be set when channel_id is present")
    else
      changeset
    end
  end

  @doc """
  Returns a query for a user's read receipt in a channel.
  """
  def channel_read_receipt_query(user_id, channel_id) do
    from rr in __MODULE__,
      where: rr.user_id == ^user_id and rr.channel_id == ^channel_id
  end

  @doc """
  Returns a query for a user's read receipt in a conversation.
  """
  def conversation_read_receipt_query(user_id, conversation_id) do
    from rr in __MODULE__,
      where: rr.user_id == ^user_id and rr.direct_conversation_id == ^conversation_id
  end

  @doc """
  Returns a query for all read receipts for a specific message.
  This is useful to see who has read a message in a channel.
  """
  def message_read_receipts_query(message_id, channel_id) do
    from rr in __MODULE__,
      where: rr.channel_id == ^channel_id and rr.last_read_message_id >= ^message_id,
      preload: [:user]
  end

  @doc """
  Gets unread message count for a user in a channel.
  """
  def unread_count_for_channel(user_id, channel_id) do
    last_read_id = get_last_read_message_id(user_id, channel_id)

    query =
      from m in Message,
        where: m.channel_id == ^channel_id and m.user_id != ^user_id and m.is_deleted == false

    query =
      if last_read_id do
        from m in query, where: m.id > ^last_read_id
      else
        query
      end

    Shadowfax.Repo.aggregate(query, :count)
  end

  @doc """
  Gets unread message count for a user in a conversation.
  """
  def unread_count_for_conversation(user_id, conversation_id) do
    last_read_id = get_last_read_message_id(user_id, {:conversation, conversation_id})

    query =
      from m in Message,
        where:
          m.direct_conversation_id == ^conversation_id and m.user_id != ^user_id and
            m.is_deleted == false

    query =
      if last_read_id do
        from m in query, where: m.id > ^last_read_id
      else
        query
      end

    Shadowfax.Repo.aggregate(query, :count)
  end

  @doc """
  Gets the last read message ID for a user in a channel or conversation.
  """
  def get_last_read_message_id(user_id, channel_id) when is_integer(channel_id) do
    from(rr in __MODULE__,
      where: rr.user_id == ^user_id and rr.channel_id == ^channel_id,
      select: rr.last_read_message_id
    )
    |> Shadowfax.Repo.one()
  end

  def get_last_read_message_id(user_id, {:conversation, conversation_id}) do
    from(rr in __MODULE__,
      where: rr.user_id == ^user_id and rr.direct_conversation_id == ^conversation_id,
      select: rr.last_read_message_id
    )
    |> Shadowfax.Repo.one()
  end

  @doc """
  Gets all read receipts for a user (useful for syncing).
  """
  def user_read_receipts_query(user_id) do
    from rr in __MODULE__,
      where: rr.user_id == ^user_id,
      preload: [:channel, :direct_conversation]
  end
end
