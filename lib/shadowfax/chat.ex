defmodule Shadowfax.Chat do
  @moduledoc """
  The Chat context.
  """

  import Ecto.Query, warn: false
  alias Shadowfax.Repo

  alias Shadowfax.Chat.{Channel, ChannelMembership, DirectConversation, Message, ReadReceipt}

  ## Channels

  @doc """
  Returns the list of public channels.

  ## Examples

      iex> list_public_channels()
      [%Channel{}, ...]

  """
  def list_public_channels do
    Channel.public_channels_query()
    |> Repo.all()
  end

  @doc """
  Returns the list of channels for a user.

  ## Examples

      iex> list_user_channels(user_id)
      [%Channel{}, ...]

  """
  def list_user_channels(user_id) do
    Channel.user_channels_query(user_id)
    |> Repo.all()
  end

  @doc """
  Gets a single channel.

  Raises `Ecto.NoResultsError` if the Channel does not exist.

  ## Examples

      iex> get_channel!(123)
      %Channel{}

      iex> get_channel!(456)
      ** (Ecto.NoResultsError)

  """
  def get_channel!(id), do: Repo.get!(Channel, id)

  @doc """
  Gets a channel by name.

  ## Examples

      iex> get_channel_by_name("general")
      %Channel{}

      iex> get_channel_by_name("nonexistent")
      nil

  """
  def get_channel_by_name(name) when is_binary(name) do
    Repo.get_by(Channel, name: String.downcase(name))
  end

  @doc """
  Creates a channel.

  ## Examples

      iex> create_channel(%{field: value})
      {:ok, %Channel{}}

      iex> create_channel(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_channel(attrs \\ %{}) do
    result =
      %Channel{}
      |> Channel.create_changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, channel} ->
        # Automatically add the creator as an owner
        case add_user_to_channel(channel.id, channel.created_by_id, "owner") do
          {:ok, _membership} -> {:ok, channel}
          {:error, _} -> result
        end

      error ->
        error
    end
  end

  @doc """
  Updates a channel.

  ## Examples

      iex> update_channel(channel, %{field: new_value})
      {:ok, %Channel{}}

      iex> update_channel(channel, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_channel(%Channel{} = channel, attrs) do
    channel
    |> Channel.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Archives/unarchives a channel.

  ## Examples

      iex> archive_channel(channel, true)
      {:ok, %Channel{}}

  """
  def archive_channel(%Channel{} = channel, is_archived) do
    channel
    |> Channel.archive_changeset(%{is_archived: is_archived})
    |> Repo.update()
  end

  @doc """
  Regenerates invite code for a private channel.

  ## Examples

      iex> regenerate_invite_code(channel)
      {:ok, %Channel{}}

  """
  def regenerate_invite_code(%Channel{is_private: true} = channel) do
    channel
    |> Channel.invite_code_changeset()
    |> Repo.update()
  end

  def regenerate_invite_code(_channel), do: {:error, :not_private_channel}

  @doc """
  Finds a channel by invite code.

  ## Examples

      iex> find_channel_by_invite_code("ABC123")
      %Channel{}

      iex> find_channel_by_invite_code("invalid")
      nil

  """
  def find_channel_by_invite_code(invite_code) do
    Channel.find_by_invite_code(invite_code)
  end

  @doc """
  Deletes a channel.

  ## Examples

      iex> delete_channel(channel)
      {:ok, %Channel{}}

      iex> delete_channel(channel)
      {:error, %Ecto.Changeset{}}

  """
  def delete_channel(%Channel{} = channel) do
    Repo.delete(channel)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking channel changes.

  ## Examples

      iex> change_channel(channel)
      %Ecto.Changeset{data: %Channel{}}

  """
  def change_channel(%Channel{} = channel, attrs \\ %{}) do
    Channel.update_changeset(channel, attrs)
  end

  ## Channel Memberships

  @doc """
  Adds a user to a channel.

  ## Examples

      iex> add_user_to_channel(channel_id, user_id, "member")
      {:ok, %ChannelMembership{}}

      iex> add_user_to_channel(channel_id, user_id, "invalid_role")
      {:error, %Ecto.Changeset{}}

  """
  def add_user_to_channel(channel_id, user_id, role \\ "member") do
    %ChannelMembership{}
    |> ChannelMembership.create_changeset(%{
      channel_id: channel_id,
      user_id: user_id,
      role: role
    })
    |> Repo.insert()
  end

  @doc """
  Removes a user from a channel.

  ## Examples

      iex> remove_user_from_channel(channel_id, user_id)
      {:ok, %ChannelMembership{}}

  """
  def remove_user_from_channel(channel_id, user_id) do
    case get_channel_membership(channel_id, user_id) do
      nil -> {:error, :not_found}
      membership -> Repo.delete(membership)
    end
  end

  @doc """
  Gets a channel membership.

  ## Examples

      iex> get_channel_membership(channel_id, user_id)
      %ChannelMembership{}

      iex> get_channel_membership(channel_id, nonexistent_user_id)
      nil

  """
  def get_channel_membership(channel_id, user_id) do
    ChannelMembership.find_membership(user_id, channel_id)
    |> Repo.one()
  end

  @doc """
  Lists all members of a channel.

  ## Examples

      iex> list_channel_members(channel_id)
      [%ChannelMembership{}, ...]

  """
  def list_channel_members(channel_id) do
    ChannelMembership.channel_memberships_query(channel_id)
    |> Repo.all()
  end

  @doc """
  Updates a user's role in a channel.

  ## Examples

      iex> update_channel_member_role(membership, %{role: "admin"})
      {:ok, %ChannelMembership{}}

  """
  def update_channel_member_role(%ChannelMembership{} = membership, attrs) do
    membership
    |> ChannelMembership.role_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates a user's channel settings.

  ## Examples

      iex> update_channel_membership(membership, %{is_muted: true})
      {:ok, %ChannelMembership{}}

  """
  def update_channel_membership(%ChannelMembership{} = membership, attrs) do
    membership
    |> ChannelMembership.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Marks all messages in a channel as read for a user.

  ## Examples

      iex> mark_channel_as_read(channel_id, user_id)
      {:ok, %ChannelMembership{}}

  """
  def mark_channel_as_read(channel_id, user_id) do
    case get_channel_membership(channel_id, user_id) do
      nil -> {:error, :not_found}
      membership -> ChannelMembership.mark_as_read(membership)
    end
  end

  ## Direct Conversations

  @doc """
  Finds or creates a direct conversation between two users.

  ## Examples

      iex> find_or_create_conversation(user1_id, user2_id)
      {:ok, %DirectConversation{}}

  """
  def find_or_create_conversation(user1_id, user2_id) do
    DirectConversation.find_or_create_conversation(user1_id, user2_id)
  end

  @doc """
  Gets a direct conversation by ID.

  ## Examples

      iex> get_direct_conversation!(123)
      %DirectConversation{}

  """
  def get_direct_conversation!(id), do: Repo.get!(DirectConversation, id)

  @doc """
  Lists all conversations for a user.

  ## Examples

      iex> list_user_conversations(user_id)
      [%DirectConversation{}, ...]

  """
  def list_user_conversations(user_id) do
    DirectConversation.user_conversations_query(user_id)
    |> Repo.all()
  end

  @doc """
  Archives/unarchives a conversation for a user.

  ## Examples

      iex> archive_conversation_for_user(conversation, user_id, true)
      {:ok, %DirectConversation{}}

  """
  def archive_conversation_for_user(%DirectConversation{} = conversation, user_id, is_archived) do
    conversation
    |> DirectConversation.archive_changeset(user_id, is_archived)
    |> Repo.update()
  end

  ## Messages

  @doc """
  Creates a channel message.

  ## Examples

      iex> create_channel_message(%{content: "Hello", user_id: 1, channel_id: 1})
      {:ok, %Message{}}

  """
  def create_channel_message(attrs \\ %{}) do
    result =
      %Message{}
      |> Message.channel_message_changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, message} ->
        # Broadcast the message to the channel
        broadcast_message(message, :new_message)
        {:ok, message}

      error ->
        error
    end
  end

  @doc """
  Creates a direct message.

  ## Examples

      iex> create_direct_message(%{content: "Hi", user_id: 1, direct_conversation_id: 1})
      {:ok, %Message{}}

  """
  def create_direct_message(attrs \\ %{}) do
    result =
      %Message{}
      |> Message.direct_message_changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, message} ->
        # Update conversation's last message time
        DirectConversation.update_last_message_time(message.direct_conversation_id)
        # Preload user for broadcasting
        message = Repo.preload(message, :user)
        # Broadcast the message
        broadcast_direct_message(message, :new_message)
        {:ok, message}

      error ->
        error
    end
  end

  @doc """
  Gets a single message.

  ## Examples

      iex> get_message!(123)
      %Message{}

  """
  def get_message!(id), do: Repo.get!(Message, id)

  @doc """
  Updates a message.

  ## Examples

      iex> update_message(message, %{content: "Updated content"})
      {:ok, %Message{}}

  """
  def update_message(%Message{} = message, attrs) do
    result =
      message
      |> Message.edit_changeset(attrs)
      |> Repo.update()

    case result do
      {:ok, updated_message} ->
        broadcast_message_update(updated_message, :message_updated)
        {:ok, updated_message}

      error ->
        error
    end
  end

  @doc """
  Soft deletes a message.

  ## Examples

      iex> delete_message(message)
      {:ok, %Message{}}

  """
  def delete_message(%Message{} = message) do
    result =
      message
      |> Message.delete_changeset()
      |> Repo.update()

    case result do
      {:ok, deleted_message} ->
        broadcast_message_update(deleted_message, :message_deleted)
        {:ok, deleted_message}

      error ->
        error
    end
  end

  @doc """
  Lists messages in a channel with cursor-based pagination.

  ## Options
  - `:limit` - Maximum number of messages to return (default: 50)
  - `:before` - Cursor (message ID) to fetch messages before
  - `:after` - Cursor (message ID) to fetch messages after

  ## Returns
  A map with:
  - `:messages` - List of messages
  - `:has_more` - Boolean indicating if more messages exist
  - `:next_cursor` - Cursor for next page (oldest message ID)
  - `:prev_cursor` - Cursor for previous page (newest message ID)

  ## Examples

      iex> list_channel_messages(channel_id, limit: 20, before: 100)
      %{messages: [...], has_more: true, next_cursor: 81, prev_cursor: 100}

  """
  def list_channel_messages(channel_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    # Fetch one extra to check if there are more messages
    messages =
      Message.channel_messages_query(channel_id, Keyword.put(opts, :limit, limit + 1))
      |> Repo.all()

    build_paginated_response(messages, limit)
  end

  @doc """
  Lists messages in a direct conversation with cursor-based pagination.

  ## Options
  - `:limit` - Maximum number of messages to return (default: 50)
  - `:before` - Cursor (message ID) to fetch messages before
  - `:after` - Cursor (message ID) to fetch messages after

  ## Returns
  A map with:
  - `:messages` - List of messages
  - `:has_more` - Boolean indicating if more messages exist
  - `:next_cursor` - Cursor for next page (oldest message ID)
  - `:prev_cursor` - Cursor for previous page (newest message ID)

  ## Examples

      iex> list_direct_messages(conversation_id, limit: 20, before: 100)
      %{messages: [...], has_more: true, next_cursor: 81, prev_cursor: 100}

  """
  def list_direct_messages(conversation_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    # Fetch one extra to check if there are more messages
    messages =
      Message.direct_messages_query(conversation_id, Keyword.put(opts, :limit, limit + 1))
      |> Repo.all()

    build_paginated_response(messages, limit)
  end

  defp build_paginated_response(messages, limit) do
    has_more = length(messages) > limit
    messages = if has_more, do: Enum.take(messages, limit), else: messages
    messages_reversed = Enum.reverse(messages)

    %{
      messages: messages_reversed,
      has_more: has_more,
      next_cursor: if(has_more && length(messages) > 0, do: List.last(messages).id, else: nil),
      prev_cursor: if(length(messages) > 0, do: List.first(messages).id, else: nil)
    }
  end

  @doc """
  Lists thread messages (replies to a parent message) with cursor-based pagination.

  ## Options
  - `:limit` - Maximum number of messages to return (default: 50)
  - `:before` - Cursor (message ID) to fetch messages before
  - `:after` - Cursor (message ID) to fetch messages after

  ## Returns
  A map with:
  - `:messages` - List of messages in chronological order
  - `:has_more` - Boolean indicating if more messages exist
  - `:next_cursor` - Cursor for next page
  - `:prev_cursor` - Cursor for previous page

  ## Examples

      iex> list_thread_messages(parent_message_id, limit: 20, before: 100)
      %{messages: [...], has_more: true, next_cursor: 120, prev_cursor: 100}

  """
  def list_thread_messages(parent_message_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    # Fetch one extra to check if there are more messages
    messages =
      Message.thread_messages_query(parent_message_id, Keyword.put(opts, :limit, limit + 1))
      |> Repo.all()

    build_thread_paginated_response(messages, limit)
  end

  defp build_thread_paginated_response(messages, limit) do
    has_more = length(messages) > limit
    messages = if has_more, do: Enum.take(messages, limit), else: messages

    %{
      messages: messages,
      has_more: has_more,
      next_cursor: if(has_more && length(messages) > 0, do: List.last(messages).id, else: nil),
      prev_cursor: if(length(messages) > 0, do: List.first(messages).id, else: nil)
    }
  end

  @doc """
  Searches messages with cursor-based pagination.

  ## Options
  - `:limit` - Maximum number of messages to return (default: 25)
  - `:before` - Cursor (message ID) to fetch messages before
  - `:after` - Cursor (message ID) to fetch messages after
  - `:channel_id` - Filter by channel ID
  - `:conversation_id` - Filter by conversation ID
  - `:user_id` - Filter by user ID

  ## Returns
  A map with:
  - `:messages` - List of messages
  - `:has_more` - Boolean indicating if more messages exist
  - `:next_cursor` - Cursor for next page (oldest message ID)
  - `:prev_cursor` - Cursor for previous page (newest message ID)

  ## Examples

      iex> search_messages("hello", channel_id: 1, limit: 20)
      %{messages: [...], has_more: false, next_cursor: nil, prev_cursor: 55}

  """
  def search_messages(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 25)

    # Fetch one extra to check if there are more messages
    messages =
      Message.search_messages_query(query, Keyword.put(opts, :limit, limit + 1))
      |> Repo.all()

    build_paginated_response(messages, limit)
  end

  @doc """
  Creates a system message.

  ## Examples

      iex> create_system_message(%{content: "User joined", channel_id: 1})
      {:ok, %Message{}}

  """
  def create_system_message(attrs \\ %{}) do
    Message.system_message_changeset(attrs)
    |> Repo.insert()
  end

  ## Real-time broadcasting

  defp broadcast_message(%Message{channel_id: channel_id} = message, event)
       when not is_nil(channel_id) do
    Phoenix.PubSub.broadcast(
      Shadowfax.PubSub,
      "channel:#{channel_id}",
      {event, message}
    )
  end

  defp broadcast_message(_, _), do: :ok

  defp broadcast_direct_message(%Message{direct_conversation_id: conv_id} = message, event)
       when not is_nil(conv_id) do
    Phoenix.PubSub.broadcast(
      Shadowfax.PubSub,
      "conversation:#{conv_id}",
      {event, message}
    )
  end

  defp broadcast_direct_message(_, _), do: :ok

  defp broadcast_message_update(message, event) do
    case Message.get_context(message) do
      {:channel, channel_id} when is_integer(channel_id) ->
        Phoenix.PubSub.broadcast(
          Shadowfax.PubSub,
          "channel:#{channel_id}",
          {event, message}
        )

      {:conversation, conv_id} when is_integer(conv_id) ->
        Phoenix.PubSub.broadcast(
          Shadowfax.PubSub,
          "conversation:#{conv_id}",
          {event, message}
        )

      _ ->
        :ok
    end
  end

  ## Utility functions

  @doc """
  Checks if a user can access a channel.
  """
  def can_access_channel?(channel_id, user_id) do
    case get_channel!(channel_id) do
      %Channel{is_private: false} -> true
      %Channel{is_private: true} -> Channel.is_member?(%Channel{id: channel_id}, user_id)
    end
  rescue
    Ecto.NoResultsError -> false
  end

  @doc """
  Checks if a user can access a conversation.
  """
  def can_access_conversation?(conversation_id, user_id) do
    case get_direct_conversation!(conversation_id) do
      %DirectConversation{user1_id: ^user_id} -> true
      %DirectConversation{user2_id: ^user_id} -> true
      _ -> false
    end
  rescue
    Ecto.NoResultsError -> false
  end

  @doc """
  Gets unread message counts for a user across all channels and conversations.
  """
  def get_unread_counts(user_id) do
    # Get unread counts for channels using read receipts
    channel_counts =
      from(cm in ChannelMembership,
        join: c in Channel,
        on: cm.channel_id == c.id,
        left_join: rr in ReadReceipt,
        on: rr.user_id == ^user_id and rr.channel_id == c.id,
        left_join: m in Message,
        on:
          m.channel_id == c.id and m.user_id != ^user_id and m.is_deleted == false and
            (is_nil(rr.last_read_message_id) or m.id > rr.last_read_message_id),
        where: cm.user_id == ^user_id and c.is_archived == false,
        group_by: [c.id, c.name],
        select: %{channel_id: c.id, channel_name: c.name, unread_count: count(m.id)}
      )
      |> Repo.all()

    # Get unread counts for conversations using read receipts
    conversation_counts =
      from(dc in DirectConversation,
        left_join: rr in ReadReceipt,
        on: rr.user_id == ^user_id and rr.direct_conversation_id == dc.id,
        left_join: m in Message,
        on:
          m.direct_conversation_id == dc.id and m.user_id != ^user_id and m.is_deleted == false and
            (is_nil(rr.last_read_message_id) or m.id > rr.last_read_message_id),
        where:
          (dc.user1_id == ^user_id and dc.is_archived_by_user1 == false) or
            (dc.user2_id == ^user_id and dc.is_archived_by_user2 == false),
        group_by: dc.id,
        select: %{conversation_id: dc.id, unread_count: count(m.id)}
      )
      |> Repo.all()

    %{
      channels: channel_counts,
      conversations: conversation_counts
    }
  end

  ## Read Receipts

  @doc """
  Marks a message as read in a channel for a user.
  Creates or updates the read receipt to track the latest message read.

  ## Examples

      iex> mark_channel_message_as_read(channel_id, user_id, message_id)
      {:ok, %ReadReceipt{}}

  """
  def mark_channel_message_as_read(channel_id, user_id, message_id) do
    # Verify the message exists and belongs to this channel
    case Repo.get(Message, message_id) do
      nil ->
        {:error, :message_not_found}

      message ->
        if message.channel_id != channel_id do
          {:error, :message_not_in_channel}
        else
          attrs = %{
            user_id: user_id,
            channel_id: channel_id,
            last_read_message_id: message_id
          }

          case get_channel_read_receipt(user_id, channel_id) do
            nil ->
              %ReadReceipt{}
              |> ReadReceipt.channel_changeset(attrs)
              |> Repo.insert()

            receipt ->
              # Only update if the new message is newer
              if message_id > receipt.last_read_message_id do
                receipt
                |> ReadReceipt.channel_changeset(attrs)
                |> Repo.update()
              else
                {:ok, receipt}
              end
          end
        end
    end
  end

  @doc """
  Marks a message as read in a conversation for a user.
  Creates or updates the read receipt to track the latest message read.

  ## Examples

      iex> mark_conversation_message_as_read(conversation_id, user_id, message_id)
      {:ok, %ReadReceipt{}}

  """
  def mark_conversation_message_as_read(conversation_id, user_id, message_id) do
    # Verify the message exists and belongs to this conversation
    case Repo.get(Message, message_id) do
      nil ->
        {:error, :message_not_found}

      message ->
        if message.direct_conversation_id != conversation_id do
          {:error, :message_not_in_conversation}
        else
          attrs = %{
            user_id: user_id,
            direct_conversation_id: conversation_id,
            last_read_message_id: message_id
          }

          case get_conversation_read_receipt(user_id, conversation_id) do
            nil ->
              %ReadReceipt{}
              |> ReadReceipt.conversation_changeset(attrs)
              |> Repo.insert()

            receipt ->
              # Only update if the new message is newer
              if message_id > receipt.last_read_message_id do
                receipt
                |> ReadReceipt.conversation_changeset(attrs)
                |> Repo.update()
              else
                {:ok, receipt}
              end
          end
        end
    end
  end

  @doc """
  Gets a user's read receipt for a channel.

  ## Examples

      iex> get_channel_read_receipt(user_id, channel_id)
      %ReadReceipt{}

  """
  def get_channel_read_receipt(user_id, channel_id) do
    ReadReceipt.channel_read_receipt_query(user_id, channel_id)
    |> Repo.one()
  end

  @doc """
  Gets a user's read receipt for a conversation.

  ## Examples

      iex> get_conversation_read_receipt(user_id, conversation_id)
      %ReadReceipt{}

  """
  def get_conversation_read_receipt(user_id, conversation_id) do
    ReadReceipt.conversation_read_receipt_query(user_id, conversation_id)
    |> Repo.one()
  end

  @doc """
  Gets all users who have read a specific message in a channel.

  ## Examples

      iex> get_message_readers(message_id, channel_id)
      [%ReadReceipt{}, ...]

  """
  def get_message_readers(message_id, channel_id) do
    ReadReceipt.message_read_receipts_query(message_id, channel_id)
    |> Repo.all()
  end

  @doc """
  Gets unread message count for a user in a channel.

  ## Examples

      iex> get_channel_unread_count(user_id, channel_id)
      5

  """
  def get_channel_unread_count(user_id, channel_id) do
    ReadReceipt.unread_count_for_channel(user_id, channel_id)
  end

  @doc """
  Gets unread message count for a user in a conversation.

  ## Examples

      iex> get_conversation_unread_count(user_id, conversation_id)
      3

  """
  def get_conversation_unread_count(user_id, conversation_id) do
    ReadReceipt.unread_count_for_conversation(user_id, conversation_id)
  end

  @doc """
  Gets all read receipts for a user (useful for initial sync).

  ## Examples

      iex> list_user_read_receipts(user_id)
      [%ReadReceipt{}, ...]

  """
  def list_user_read_receipts(user_id) do
    ReadReceipt.user_read_receipts_query(user_id)
    |> Repo.all()
  end
end
