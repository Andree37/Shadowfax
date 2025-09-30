defmodule Shadowfax.Chat do
  @moduledoc """
  The Chat context.
  """

  import Ecto.Query, warn: false
  alias Shadowfax.Repo

  alias Shadowfax.Accounts.User
  alias Shadowfax.Chat.{Channel, ChannelMembership, DirectConversation, Message}

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
  Lists messages in a channel.

  ## Examples

      iex> list_channel_messages(channel_id)
      [%Message{}, ...]

  """
  def list_channel_messages(channel_id, opts \\ []) do
    Message.channel_messages_query(channel_id, opts)
    |> Repo.all()
    |> Enum.reverse()
  end

  @doc """
  Lists messages in a direct conversation.

  ## Examples

      iex> list_direct_messages(conversation_id)
      [%Message{}, ...]

  """
  def list_direct_messages(conversation_id, opts \\ []) do
    Message.direct_messages_query(conversation_id, opts)
    |> Repo.all()
    |> Enum.reverse()
  end

  @doc """
  Lists thread messages (replies to a parent message).

  ## Examples

      iex> list_thread_messages(parent_message_id)
      [%Message{}, ...]

  """
  def list_thread_messages(parent_message_id) do
    Message.thread_messages_query(parent_message_id)
    |> Repo.all()
  end

  @doc """
  Searches messages.

  ## Examples

      iex> search_messages("hello", channel_id: 1)
      [%Message{}, ...]

  """
  def search_messages(query, opts \\ []) do
    Message.search_messages_query(query, opts)
    |> Repo.all()
  end

  @doc """
  Creates a system message.

  ## Examples

      iex> create_system_message(%{content: "User joined", channel_id: 1})
      {:ok, %Message{}}

  """
  def create_system_message(attrs \\ %{}) do
    %Message{}
    |> Message.system_message_changeset(attrs)
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
    # Get unread counts for channels
    channel_counts =
      from(cm in ChannelMembership,
        join: c in Channel,
        on: cm.channel_id == c.id,
        left_join: m in Message,
        on:
          m.channel_id == c.id and
            (is_nil(cm.last_read_at) or m.inserted_at > cm.last_read_at) and
            m.user_id != ^user_id and
            m.is_deleted == false,
        where: cm.user_id == ^user_id and c.is_archived == false,
        group_by: [c.id, c.name],
        select: %{channel_id: c.id, channel_name: c.name, unread_count: count(m.id)}
      )
      |> Repo.all()

    # Get unread counts for conversations
    conversation_counts =
      from(dc in DirectConversation,
        left_join: m in Message,
        on:
          m.direct_conversation_id == dc.id and
            m.user_id != ^user_id and
            m.is_deleted == false,
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
end
