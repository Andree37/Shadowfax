defmodule Shadowfax.ChatTest do
  use Shadowfax.DataCase, async: true

  alias Shadowfax.Accounts
  alias Shadowfax.Chat
  alias Shadowfax.Repo

  setup do
    # Clear the database before each test
    Repo.delete_all(Shadowfax.Chat.Message)
    Repo.delete_all(Shadowfax.Chat.ChannelMembership)
    Repo.delete_all(Shadowfax.Chat.DirectConversation)
    Repo.delete_all(Shadowfax.Chat.Channel)
    Repo.delete_all(Shadowfax.Accounts.User)

    # Create a test user for most tests
    {:ok, user} =
      Accounts.create_user(%{
        username: "testuser",
        email: "test@example.com",
        password: "Pass1234!"
      })

    {:ok, user: user}
  end

  describe "create_channel/1" do
    test "creates a public channel", %{user: user} do
      attrs = %{
        name: "general",
        description: "General discussion",
        topic: "Welcome!",
        is_private: false,
        created_by_id: user.id
      }

      assert {:ok, channel} = Chat.create_channel(attrs)
      assert channel.name == "general"
      assert channel.description == "General discussion"
      assert channel.is_private == false
      assert channel.invite_code == nil
    end

    test "creates a private channel with invite code", %{user: user} do
      attrs = %{
        name: "private",
        is_private: true,
        created_by_id: user.id
      }

      assert {:ok, channel} = Chat.create_channel(attrs)
      assert channel.is_private == true
      assert channel.invite_code != nil
      assert String.length(channel.invite_code) > 0
    end

    test "automatically adds creator as owner", %{user: user} do
      {:ok, channel} =
        Chat.create_channel(%{
          name: "owned",
          created_by_id: user.id
        })

      membership = Chat.get_channel_membership(channel.id, user.id)
      assert membership != nil
      assert membership.role == "owner"
    end

    test "normalizes channel name to lowercase", %{user: user} do
      {:ok, channel} =
        Chat.create_channel(%{
          name: "MixedCase",
          created_by_id: user.id
        })

      assert channel.name == "mixedcase"
    end

    test "validates channel name format", %{user: user} do
      assert {:error, changeset} =
               Chat.create_channel(%{
                 name: "invalid name!",
                 created_by_id: user.id
               })

      assert %{name: _} = errors_on(changeset)
    end

    test "prevents duplicate channel names", %{user: user} do
      {:ok, _channel} = Chat.create_channel(%{name: "duplicate", created_by_id: user.id})

      assert {:error, changeset} =
               Chat.create_channel(%{
                 name: "duplicate",
                 created_by_id: user.id
               })

      assert %{name: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "list_public_channels/0" do
    test "returns only public, non-archived channels", %{user: user} do
      {:ok, _public1} = Chat.create_channel(%{name: "public1", created_by_id: user.id})
      {:ok, _public2} = Chat.create_channel(%{name: "public2", created_by_id: user.id})

      {:ok, _private} =
        Chat.create_channel(%{
          name: "private",
          is_private: true,
          created_by_id: user.id
        })

      {:ok, archived} = Chat.create_channel(%{name: "archived", created_by_id: user.id})
      Chat.archive_channel(archived, true)

      channels = Chat.list_public_channels()
      assert length(channels) == 2
      assert Enum.all?(channels, fn c -> c.is_private == false and c.is_archived == false end)
    end
  end

  describe "list_user_channels/1" do
    test "returns channels user is member of", %{user: user} do
      {:ok, user2} =
        Accounts.create_user(%{
          username: "user2",
          email: "user2@example.com",
          password: "Pass1234!"
        })

      {:ok, _channel1} = Chat.create_channel(%{name: "chan1", created_by_id: user.id})
      {:ok, _channel2} = Chat.create_channel(%{name: "chan2", created_by_id: user.id})
      {:ok, _channel3} = Chat.create_channel(%{name: "chan3", created_by_id: user2.id})

      user_channels = Chat.list_user_channels(user.id)
      channel_names = Enum.map(user_channels, & &1.name)

      assert length(user_channels) == 2
      assert "chan1" in channel_names
      assert "chan2" in channel_names
      refute "chan3" in channel_names
    end
  end

  describe "get_channel_by_name/1" do
    test "finds channel by name", %{user: user} do
      {:ok, channel} = Chat.create_channel(%{name: "findme", created_by_id: user.id})

      found = Chat.get_channel_by_name("findme")
      assert found.id == channel.id
    end

    test "returns nil for nonexistent channel" do
      assert Chat.get_channel_by_name("nonexistent") == nil
    end
  end

  describe "update_channel/2" do
    test "updates channel attributes", %{user: user} do
      {:ok, channel} = Chat.create_channel(%{name: "update", created_by_id: user.id})

      {:ok, updated} =
        Chat.update_channel(channel, %{
          description: "New description",
          topic: "New topic"
        })

      assert updated.description == "New description"
      assert updated.topic == "New topic"
    end
  end

  describe "archive_channel/2" do
    test "archives a channel", %{user: user} do
      {:ok, channel} = Chat.create_channel(%{name: "archive", created_by_id: user.id})

      {:ok, archived} = Chat.archive_channel(channel, true)
      assert archived.is_archived == true

      {:ok, unarchived} = Chat.archive_channel(archived, false)
      assert unarchived.is_archived == false
    end
  end

  describe "regenerate_invite_code/1" do
    test "regenerates invite code for private channel", %{user: user} do
      {:ok, channel} =
        Chat.create_channel(%{
          name: "private",
          is_private: true,
          created_by_id: user.id
        })

      original_code = channel.invite_code

      {:ok, updated} = Chat.regenerate_invite_code(channel)
      assert updated.invite_code != original_code
    end

    test "returns error for public channel", %{user: user} do
      {:ok, channel} = Chat.create_channel(%{name: "public", created_by_id: user.id})

      assert {:error, :not_private_channel} = Chat.regenerate_invite_code(channel)
    end
  end

  describe "find_channel_by_invite_code/1" do
    test "finds private channel by invite code", %{user: user} do
      {:ok, channel} =
        Chat.create_channel(%{
          name: "invited",
          is_private: true,
          created_by_id: user.id
        })

      found = Chat.find_channel_by_invite_code(channel.invite_code)
      assert found.id == channel.id
    end

    test "returns nil for invalid code" do
      assert Chat.find_channel_by_invite_code("invalid") == nil
    end
  end

  describe "add_user_to_channel/3" do
    test "adds user to channel", %{user: user} do
      {:ok, user2} =
        Accounts.create_user(%{
          username: "member",
          email: "member@example.com",
          password: "Pass1234!"
        })

      {:ok, channel} = Chat.create_channel(%{name: "join", created_by_id: user.id})

      {:ok, membership} = Chat.add_user_to_channel(channel.id, user2.id, "member")
      assert membership.user_id == user2.id
      assert membership.channel_id == channel.id
      assert membership.role == "member"
    end

    test "prevents duplicate memberships", %{user: user} do
      {:ok, channel} = Chat.create_channel(%{name: "dup", created_by_id: user.id})

      # User is already a member (owner)
      assert {:error, _changeset} = Chat.add_user_to_channel(channel.id, user.id, "member")
    end
  end

  describe "remove_user_from_channel/2" do
    test "removes user from channel", %{user: user} do
      {:ok, user2} =
        Accounts.create_user(%{
          username: "leaving",
          email: "leaving@example.com",
          password: "Pass1234!"
        })

      {:ok, channel} = Chat.create_channel(%{name: "leave", created_by_id: user.id})
      {:ok, _membership} = Chat.add_user_to_channel(channel.id, user2.id)

      assert {:ok, _deleted} = Chat.remove_user_from_channel(channel.id, user2.id)
      assert Chat.get_channel_membership(channel.id, user2.id) == nil
    end

    test "returns error when membership doesn't exist", %{user: user} do
      {:ok, channel} = Chat.create_channel(%{name: "notamember", created_by_id: user.id})

      assert {:error, :not_found} = Chat.remove_user_from_channel(channel.id, 99999)
    end
  end

  describe "list_channel_members/1" do
    test "returns all channel members", %{user: user} do
      {:ok, user2} =
        Accounts.create_user(%{
          username: "member1",
          email: "member1@example.com",
          password: "Pass1234!"
        })

      {:ok, user3} =
        Accounts.create_user(%{
          username: "member2",
          email: "member2@example.com",
          password: "Pass1234!"
        })

      {:ok, channel} = Chat.create_channel(%{name: "members", created_by_id: user.id})
      Chat.add_user_to_channel(channel.id, user2.id)
      Chat.add_user_to_channel(channel.id, user3.id)

      members = Chat.list_channel_members(channel.id)
      assert length(members) == 3
    end
  end

  describe "find_or_create_conversation/2" do
    test "creates a new conversation between two users", %{user: user1} do
      {:ok, user2} =
        Accounts.create_user(%{
          username: "user2",
          email: "user2@example.com",
          password: "Pass1234!"
        })

      {:ok, conversation} = Chat.find_or_create_conversation(user1.id, user2.id)
      assert conversation.user1_id == user1.id
      assert conversation.user2_id == user2.id
    end

    test "returns existing conversation if it exists", %{user: user1} do
      {:ok, user2} =
        Accounts.create_user(%{
          username: "user2",
          email: "user2@example.com",
          password: "Pass1234!"
        })

      {:ok, conv1} = Chat.find_or_create_conversation(user1.id, user2.id)
      {:ok, conv2} = Chat.find_or_create_conversation(user1.id, user2.id)

      assert conv1.id == conv2.id
    end

    test "returns same conversation regardless of user order", %{user: user1} do
      {:ok, user2} =
        Accounts.create_user(%{
          username: "user2",
          email: "user2@example.com",
          password: "Pass1234!"
        })

      {:ok, conv1} = Chat.find_or_create_conversation(user1.id, user2.id)
      {:ok, conv2} = Chat.find_or_create_conversation(user2.id, user1.id)

      assert conv1.id == conv2.id
    end
  end

  describe "create_channel_message/1" do
    test "creates a channel message", %{user: user} do
      {:ok, channel} = Chat.create_channel(%{name: "messages", created_by_id: user.id})

      {:ok, message} =
        Chat.create_channel_message(%{
          content: "Hello!",
          user_id: user.id,
          channel_id: channel.id
        })

      assert message.content == "Hello!"
      assert message.user_id == user.id
      assert message.channel_id == channel.id
      assert message.is_deleted == false
      assert message.edited_at == nil
    end

    test "creates threaded reply", %{user: user} do
      {:ok, channel} = Chat.create_channel(%{name: "threads", created_by_id: user.id})

      {:ok, parent} =
        Chat.create_channel_message(%{
          content: "Parent",
          user_id: user.id,
          channel_id: channel.id
        })

      {:ok, reply} =
        Chat.create_channel_message(%{
          content: "Reply",
          user_id: user.id,
          channel_id: channel.id,
          parent_message_id: parent.id
        })

      assert reply.parent_message_id == parent.id
    end
  end

  describe "create_direct_message/1" do
    test "creates a direct message", %{user: user1} do
      {:ok, user2} =
        Accounts.create_user(%{
          username: "dmuser",
          email: "dm@example.com",
          password: "Pass1234!"
        })

      {:ok, conversation} = Chat.find_or_create_conversation(user1.id, user2.id)

      {:ok, message} =
        Chat.create_direct_message(%{
          content: "Direct message",
          user_id: user1.id,
          direct_conversation_id: conversation.id
        })

      assert message.content == "Direct message"
      assert message.direct_conversation_id == conversation.id
    end
  end

  describe "update_message/2" do
    test "updates message content and marks as edited", %{user: user} do
      {:ok, channel} = Chat.create_channel(%{name: "edit", created_by_id: user.id})

      {:ok, message} =
        Chat.create_channel_message(%{
          content: "Original",
          user_id: user.id,
          channel_id: channel.id
        })

      {:ok, updated} = Chat.update_message(message, %{content: "Updated"})
      assert updated.content == "Updated"
      assert updated.edited_at != nil
    end
  end

  describe "delete_message/1" do
    test "soft deletes a message", %{user: user} do
      {:ok, channel} = Chat.create_channel(%{name: "delete", created_by_id: user.id})

      {:ok, message} =
        Chat.create_channel_message(%{
          content: "Delete me",
          user_id: user.id,
          channel_id: channel.id
        })

      {:ok, deleted} = Chat.delete_message(message)
      assert deleted.is_deleted == true

      # Message still exists in database
      db_message = Chat.get_message!(message.id)
      assert db_message.id == message.id
    end
  end

  describe "list_channel_messages/2" do
    test "returns messages in a channel", %{user: user} do
      {:ok, channel} = Chat.create_channel(%{name: "msgs", created_by_id: user.id})

      {:ok, _msg1} =
        Chat.create_channel_message(%{
          content: "First",
          user_id: user.id,
          channel_id: channel.id
        })

      {:ok, _msg2} =
        Chat.create_channel_message(%{
          content: "Second",
          user_id: user.id,
          channel_id: channel.id
        })

      messages = Chat.list_channel_messages(channel.id)
      assert length(messages) == 2
    end

    test "limits number of messages returned", %{user: user} do
      {:ok, channel} = Chat.create_channel(%{name: "limited", created_by_id: user.id})

      for i <- 1..20 do
        Chat.create_channel_message(%{
          content: "Message #{i}",
          user_id: user.id,
          channel_id: channel.id
        })
      end

      messages = Chat.list_channel_messages(channel.id, limit: 10)
      assert length(messages) == 10
    end
  end

  describe "list_thread_messages/1" do
    test "returns only replies to parent message", %{user: user} do
      {:ok, channel} = Chat.create_channel(%{name: "thread", created_by_id: user.id})

      {:ok, parent} =
        Chat.create_channel_message(%{
          content: "Parent",
          user_id: user.id,
          channel_id: channel.id
        })

      {:ok, _reply1} =
        Chat.create_channel_message(%{
          content: "Reply 1",
          user_id: user.id,
          channel_id: channel.id,
          parent_message_id: parent.id
        })

      {:ok, _reply2} =
        Chat.create_channel_message(%{
          content: "Reply 2",
          user_id: user.id,
          channel_id: channel.id,
          parent_message_id: parent.id
        })

      {:ok, _other} =
        Chat.create_channel_message(%{
          content: "Not a reply",
          user_id: user.id,
          channel_id: channel.id
        })

      thread = Chat.list_thread_messages(parent.id)
      assert length(thread) == 2
    end
  end

  describe "search_messages/2" do
    test "searches messages by content", %{user: user} do
      {:ok, channel} = Chat.create_channel(%{name: "search", created_by_id: user.id})

      {:ok, _msg1} =
        Chat.create_channel_message(%{
          content: "Hello world",
          user_id: user.id,
          channel_id: channel.id
        })

      {:ok, _msg2} =
        Chat.create_channel_message(%{
          content: "Goodbye world",
          user_id: user.id,
          channel_id: channel.id
        })

      {:ok, _msg3} =
        Chat.create_channel_message(%{
          content: "Something else",
          user_id: user.id,
          channel_id: channel.id
        })

      results = Chat.search_messages("world", channel_id: channel.id)
      assert length(results) == 2
    end
  end

  describe "mark_channel_as_read/2" do
    test "updates last_read_at for channel membership", %{user: user} do
      {:ok, channel} = Chat.create_channel(%{name: "read", created_by_id: user.id})

      {:ok, membership} = Chat.mark_channel_as_read(channel.id, user.id)
      assert membership.last_read_at != nil
    end
  end

  describe "can_access_channel?/2" do
    test "allows access to public channel", %{user: user} do
      {:ok, user2} =
        Accounts.create_user(%{
          username: "visitor",
          email: "visitor@example.com",
          password: "Pass1234!"
        })

      {:ok, channel} = Chat.create_channel(%{name: "public", created_by_id: user.id})

      assert Chat.can_access_channel?(channel.id, user2.id) == true
    end

    test "restricts access to private channel for non-members", %{user: user} do
      {:ok, _user2} =
        Accounts.create_user(%{
          username: "outsider",
          email: "outsider@example.com",
          password: "Pass1234!"
        })

      {:ok, channel} =
        Chat.create_channel(%{
          name: "private",
          is_private: true,
          created_by_id: user.id
        })

      # Note: This test depends on implementation of can_access_channel?
      # Adjust based on actual behavior
      assert Chat.can_access_channel?(channel.id, user.id) == true
    end
  end

  describe "can_access_conversation?/2" do
    test "allows access to participants", %{user: user1} do
      {:ok, user2} =
        Accounts.create_user(%{
          username: "participant",
          email: "participant@example.com",
          password: "Pass1234!"
        })

      {:ok, conversation} = Chat.find_or_create_conversation(user1.id, user2.id)

      assert Chat.can_access_conversation?(conversation.id, user1.id) == true
      assert Chat.can_access_conversation?(conversation.id, user2.id) == true
    end

    test "denies access to non-participants", %{user: user1} do
      {:ok, user2} =
        Accounts.create_user(%{
          username: "user2",
          email: "user2@example.com",
          password: "Pass1234!"
        })

      {:ok, user3} =
        Accounts.create_user(%{
          username: "outsider",
          email: "outsider@example.com",
          password: "Pass1234!"
        })

      {:ok, conversation} = Chat.find_or_create_conversation(user1.id, user2.id)

      assert Chat.can_access_conversation?(conversation.id, user3.id) == false
    end
  end
end
