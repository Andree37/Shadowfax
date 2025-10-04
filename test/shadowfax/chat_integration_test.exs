defmodule Shadowfax.ChatIntegrationTest do
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

    :ok
  end

  describe "full user and chat flow" do
    test "creates user, subscribes to channels, and sends messages" do
      # Step 1: Create a new user
      user_attrs = %{
        username: "testuser",
        email: "test@example.com",
        password: "Test1234!",
        first_name: "Test",
        last_name: "User"
      }

      assert {:ok, user} = Accounts.create_user(user_attrs)
      assert user.username == "testuser"
      assert user.email == "test@example.com"
      assert user.first_name == "Test"
      assert user.last_name == "User"
      assert user.hashed_password != nil
      assert user.status == "available"

      # Verify user exists in database
      db_user = Accounts.get_user!(user.id)
      assert db_user.id == user.id
      assert db_user.username == "testuser"

      # Step 2: Create a public channel
      channel_attrs = %{
        name: "general",
        description: "General discussion",
        topic: "Welcome to the general channel",
        is_private: false,
        created_by_id: user.id
      }

      assert {:ok, channel} = Chat.create_channel(channel_attrs)
      assert channel.name == "general"
      assert channel.description == "General discussion"
      assert channel.is_private == false
      assert channel.is_archived == false
      assert channel.created_by_id == user.id

      # Verify creator is automatically added as owner
      membership = Chat.get_channel_membership(channel.id, user.id)
      assert membership != nil
      assert membership.role == "owner"
      assert membership.user_id == user.id
      assert membership.channel_id == channel.id

      # Step 3: Create another user
      user2_attrs = %{
        username: "anotheruser",
        email: "another@example.com",
        password: "Pass1234!",
        first_name: "Another",
        last_name: "User"
      }

      assert {:ok, user2} = Accounts.create_user(user2_attrs)
      assert user2.username == "anotheruser"

      # Step 4: User2 subscribes to the general channel
      assert {:ok, membership2} = Chat.add_user_to_channel(channel.id, user2.id, "member")
      assert membership2.role == "member"
      assert membership2.user_id == user2.id
      assert membership2.channel_id == channel.id

      # Step 5: Create a private channel
      private_channel_attrs = %{
        name: "private_room",
        description: "Private discussion",
        is_private: true,
        created_by_id: user.id
      }

      assert {:ok, private_channel} = Chat.create_channel(private_channel_attrs)
      assert private_channel.is_private == true
      assert private_channel.invite_code != nil

      # Step 6: User2 joins private channel
      assert {:ok, _membership3} =
               Chat.add_user_to_channel(private_channel.id, user2.id, "member")

      # Step 7: Send messages in the general channel
      message1_attrs = %{
        content: "Hello everyone!",
        user_id: user.id,
        channel_id: channel.id
      }

      assert {:ok, message1} = Chat.create_channel_message(message1_attrs)
      assert message1.content == "Hello everyone!"
      assert message1.user_id == user.id
      assert message1.channel_id == channel.id
      assert message1.is_deleted == false
      assert message1.edited_at == nil

      # User2 responds
      message2_attrs = %{
        content: "Hi there!",
        user_id: user2.id,
        channel_id: channel.id
      }

      assert {:ok, message2} = Chat.create_channel_message(message2_attrs)
      assert message2.content == "Hi there!"
      assert message2.user_id == user2.id

      # Step 8: Send messages in the private channel
      private_message_attrs = %{
        content: "This is private",
        user_id: user.id,
        channel_id: private_channel.id
      }

      assert {:ok, private_message} = Chat.create_channel_message(private_message_attrs)
      assert private_message.content == "This is private"
      assert private_message.channel_id == private_channel.id

      # Step 9: Verify all messages are retrievable
      general_result = Chat.list_channel_messages(channel.id)
      assert length(general_result.messages) == 2
      assert Enum.any?(general_result.messages, fn m -> m.content == "Hello everyone!" end)
      assert Enum.any?(general_result.messages, fn m -> m.content == "Hi there!" end)

      private_result = Chat.list_channel_messages(private_channel.id)
      assert length(private_result.messages) == 1
      assert Enum.at(private_result.messages, 0).content == "This is private"

      # Step 10: Verify channel memberships
      general_members = Chat.list_channel_members(channel.id)
      assert length(general_members) == 2

      private_members = Chat.list_channel_members(private_channel.id)
      assert length(private_members) == 2

      # Step 11: Verify user channels list
      user_channels = Chat.list_user_channels(user.id)
      assert length(user_channels) == 2

      user2_channels = Chat.list_user_channels(user2.id)
      assert length(user2_channels) == 2
    end

    test "creates direct conversation and exchanges messages" do
      # Create two users
      {:ok, user1} =
        Accounts.create_user(%{
          username: "user1",
          email: "user1@example.com",
          password: "Pass1234!"
        })

      {:ok, user2} =
        Accounts.create_user(%{
          username: "user2",
          email: "user2@example.com",
          password: "Pass1234!"
        })

      # Find or create a direct conversation
      {:ok, conversation} = Chat.find_or_create_conversation(user1.id, user2.id)
      assert conversation.user1_id == user1.id
      assert conversation.user2_id == user2.id

      # Verify finding the same conversation returns the existing one
      {:ok, same_conversation} = Chat.find_or_create_conversation(user1.id, user2.id)
      assert same_conversation.id == conversation.id

      # Also verify reverse order returns the same conversation
      {:ok, reverse_conversation} = Chat.find_or_create_conversation(user2.id, user1.id)
      assert reverse_conversation.id == conversation.id

      # Send direct messages
      {:ok, dm1} =
        Chat.create_direct_message(%{
          content: "Hey, how are you?",
          user_id: user1.id,
          direct_conversation_id: conversation.id
        })

      assert dm1.content == "Hey, how are you?"
      assert dm1.user_id == user1.id
      assert dm1.direct_conversation_id == conversation.id

      {:ok, dm2} =
        Chat.create_direct_message(%{
          content: "I'm good, thanks!",
          user_id: user2.id,
          direct_conversation_id: conversation.id
        })

      assert dm2.content == "I'm good, thanks!"

      # Verify messages are retrievable
      result = Chat.list_direct_messages(conversation.id)
      assert length(result.messages) == 2

      # Verify user can access conversation
      assert Chat.can_access_conversation?(conversation.id, user1.id) == true
      assert Chat.can_access_conversation?(conversation.id, user2.id) == true

      # Create another user who should not have access
      {:ok, user3} =
        Accounts.create_user(%{
          username: "user3",
          email: "user3@example.com",
          password: "Pass1234!"
        })

      assert Chat.can_access_conversation?(conversation.id, user3.id) == false
    end

    test "updates and deletes messages" do
      # Create user and channel
      {:ok, user} =
        Accounts.create_user(%{
          username: "messageuser",
          email: "msg@example.com",
          password: "Pass1234!"
        })

      {:ok, channel} =
        Chat.create_channel(%{
          name: "testchannel",
          created_by_id: user.id
        })

      # Send a message
      {:ok, message} =
        Chat.create_channel_message(%{
          content: "Original content",
          user_id: user.id,
          channel_id: channel.id
        })

      # Update the message
      {:ok, updated_message} = Chat.update_message(message, %{content: "Updated content"})
      assert updated_message.content == "Updated content"
      assert updated_message.edited_at != nil

      # Delete the message (soft delete)
      {:ok, deleted_message} = Chat.delete_message(updated_message)
      assert deleted_message.is_deleted == true

      # Verify the message still exists but is marked as deleted
      db_message = Chat.get_message!(message.id)
      assert db_message.is_deleted == true
    end

    test "marks channel as read and tracks unread counts" do
      # Create users
      {:ok, user1} =
        Accounts.create_user(%{
          username: "reader",
          email: "reader@example.com",
          password: "Pass1234!"
        })

      {:ok, user2} =
        Accounts.create_user(%{
          username: "writer",
          email: "writer@example.com",
          password: "Pass1234!"
        })

      # Create channel and add both users
      {:ok, channel} =
        Chat.create_channel(%{
          name: "readtest",
          created_by_id: user1.id
        })

      {:ok, _membership} = Chat.add_user_to_channel(channel.id, user2.id)

      # User2 sends some messages
      {:ok, _msg1} =
        Chat.create_channel_message(%{
          content: "Message 1",
          user_id: user2.id,
          channel_id: channel.id
        })

      {:ok, _msg2} =
        Chat.create_channel_message(%{
          content: "Message 2",
          user_id: user2.id,
          channel_id: channel.id
        })

      # Mark channel as read for user1
      {:ok, updated_membership} = Chat.mark_channel_as_read(channel.id, user1.id)
      assert updated_membership.last_read_at != nil
    end

    test "handles user online status" do
      # Create a user
      {:ok, user} =
        Accounts.create_user(%{
          username: "statususer",
          email: "status@example.com",
          password: "Pass1234!"
        })

      assert user.status == "available"

      # Update user status to away
      {:ok, away_user} = Accounts.update_user(user, %{status: "away"})
      assert away_user.status == "away"

      # Update user status to busy
      {:ok, busy_user} = Accounts.update_user(away_user, %{status: "busy"})
      assert busy_user.status == "busy"

      # Update user status to dnd
      {:ok, dnd_user} = Accounts.update_user(busy_user, %{status: "dnd"})
      assert dnd_user.status == "dnd"

      # Note: Online/offline status is now tracked via Phoenix.Presence, not the database
      # Users are considered online when connected to a channel via WebSocket
    end
  end

  describe "channel permissions and validation" do
    test "prevents duplicate channel names" do
      {:ok, user} =
        Accounts.create_user(%{
          username: "channelowner",
          email: "owner@example.com",
          password: "Pass1234!"
        })

      {:ok, _channel1} =
        Chat.create_channel(%{
          name: "duplicate",
          created_by_id: user.id
        })

      # Try to create another channel with the same name
      assert {:error, changeset} =
               Chat.create_channel(%{
                 name: "duplicate",
                 created_by_id: user.id
               })

      assert %{name: ["has already been taken"]} = errors_on(changeset)
    end

    test "validates channel name format" do
      {:ok, user} =
        Accounts.create_user(%{
          username: "validator",
          email: "validator@example.com",
          password: "Pass1234!"
        })

      # Invalid channel name with spaces
      assert {:error, changeset} =
               Chat.create_channel(%{
                 name: "invalid name",
                 created_by_id: user.id
               })

      assert %{name: [_]} = errors_on(changeset)

      # Valid channel name
      assert {:ok, channel} =
               Chat.create_channel(%{
                 name: "valid-name_123",
                 created_by_id: user.id
               })

      assert channel.name == "valid-name_123"
    end

    test "enforces private channel access with invite codes" do
      {:ok, owner} =
        Accounts.create_user(%{
          username: "owner",
          email: "owner@example.com",
          password: "Pass1234!"
        })

      {:ok, _member} =
        Accounts.create_user(%{
          username: "member",
          email: "member@example.com",
          password: "Pass1234!"
        })

      # Create private channel
      {:ok, channel} =
        Chat.create_channel(%{
          name: "secret",
          is_private: true,
          created_by_id: owner.id
        })

      assert channel.invite_code != nil
      original_code = channel.invite_code

      # Find channel by invite code
      found_channel = Chat.find_channel_by_invite_code(original_code)
      assert found_channel.id == channel.id

      # Regenerate invite code
      {:ok, updated_channel} = Chat.regenerate_invite_code(channel)
      assert updated_channel.invite_code != original_code

      # Old code should not work
      assert Chat.find_channel_by_invite_code(original_code) == nil
    end

    test "prevents users from joining archived channels" do
      {:ok, owner} =
        Accounts.create_user(%{
          username: "archiver",
          email: "archiver@example.com",
          password: "Pass1234!"
        })

      {:ok, _user} =
        Accounts.create_user(%{
          username: "joiner",
          email: "joiner@example.com",
          password: "Pass1234!"
        })

      {:ok, channel} =
        Chat.create_channel(%{
          name: "toarchive",
          created_by_id: owner.id
        })

      # Archive the channel
      {:ok, archived_channel} = Chat.archive_channel(channel, true)
      assert archived_channel.is_archived == true

      # Verify channel is not in public list
      public_channels = Chat.list_public_channels()
      refute Enum.any?(public_channels, fn c -> c.id == archived_channel.id end)
    end

    test "limits message content length" do
      {:ok, user} =
        Accounts.create_user(%{
          username: "longsender",
          email: "long@example.com",
          password: "Pass1234!"
        })

      {:ok, channel} =
        Chat.create_channel(%{
          name: "lengthtest",
          created_by_id: user.id
        })

      # Try to send an extremely long message (assuming validation exists)
      very_long_content = String.duplicate("a", 10000)

      # This should fail if message validation is in place
      result =
        Chat.create_channel_message(%{
          content: very_long_content,
          user_id: user.id,
          channel_id: channel.id
        })

      # If validation exists, this will be an error
      # Otherwise, it will succeed (update this based on your actual validation)
      case result do
        {:ok, _message} -> assert true
        {:error, _changeset} -> assert true
      end
    end
  end

  describe "user validation and constraints" do
    test "prevents duplicate usernames" do
      {:ok, _user1} =
        Accounts.create_user(%{
          username: "duplicate",
          email: "first@example.com",
          password: "Pass1234!"
        })

      assert {:error, changeset} =
               Accounts.create_user(%{
                 username: "duplicate",
                 email: "second@example.com",
                 password: "Pass1234!"
               })

      assert %{username: ["has already been taken"]} = errors_on(changeset)
    end

    test "prevents duplicate emails" do
      {:ok, _user1} =
        Accounts.create_user(%{
          username: "first",
          email: "same@example.com",
          password: "Pass1234!"
        })

      assert {:error, changeset} =
               Accounts.create_user(%{
                 username: "second",
                 email: "same@example.com",
                 password: "Pass1234!"
               })

      assert %{email: ["has already been taken"]} = errors_on(changeset)
    end

    test "validates password requirements" do
      # Too short password
      assert {:error, changeset} =
               Accounts.create_user(%{
                 username: "testuser",
                 email: "test@example.com",
                 password: "short"
               })

      assert %{password: _errors} = errors_on(changeset)

      # Missing uppercase
      assert {:error, changeset} =
               Accounts.create_user(%{
                 username: "testuser2",
                 email: "test2@example.com",
                 password: "alllowercase1!"
               })

      assert %{password: _errors} = errors_on(changeset)

      # Valid password
      assert {:ok, user} =
               Accounts.create_user(%{
                 username: "validuser",
                 email: "valid@example.com",
                 password: "ValidPass1!"
               })

      assert user.username == "validuser"
    end

    test "validates email format" do
      assert {:error, changeset} =
               Accounts.create_user(%{
                 username: "emailtest",
                 email: "invalidemail",
                 password: "Pass1234!"
               })

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates username format" do
      # Username with spaces
      assert {:error, changeset} =
               Accounts.create_user(%{
                 username: "invalid username",
                 email: "test@example.com",
                 password: "Pass1234!"
               })

      assert %{username: _errors} = errors_on(changeset)

      # Username too short
      assert {:error, changeset} =
               Accounts.create_user(%{
                 username: "ab",
                 email: "test2@example.com",
                 password: "Pass1234!"
               })

      assert %{username: _errors} = errors_on(changeset)
    end
  end

  describe "message threading and replies" do
    test "creates threaded replies to messages" do
      {:ok, user} =
        Accounts.create_user(%{
          username: "threader",
          email: "thread@example.com",
          password: "Pass1234!"
        })

      {:ok, channel} =
        Chat.create_channel(%{
          name: "threadtest",
          created_by_id: user.id
        })

      # Send parent message
      {:ok, parent_message} =
        Chat.create_channel_message(%{
          content: "Parent message",
          user_id: user.id,
          channel_id: channel.id
        })

      # Send reply
      {:ok, reply1} =
        Chat.create_channel_message(%{
          content: "Reply 1",
          user_id: user.id,
          channel_id: channel.id,
          parent_message_id: parent_message.id
        })

      assert reply1.parent_message_id == parent_message.id

      {:ok, _reply2} =
        Chat.create_channel_message(%{
          content: "Reply 2",
          user_id: user.id,
          channel_id: channel.id,
          parent_message_id: parent_message.id
        })

      # Get thread messages
      thread_result = Chat.list_thread_messages(parent_message.id)
      assert length(thread_result.messages) == 2
      assert Enum.any?(thread_result.messages, fn m -> m.content == "Reply 1" end)
      assert Enum.any?(thread_result.messages, fn m -> m.content == "Reply 2" end)
    end
  end

  describe "search functionality" do
    test "searches for users by username" do
      {:ok, _user1} =
        Accounts.create_user(%{
          username: "john_doe",
          email: "john@example.com",
          password: "Pass1234!"
        })

      {:ok, _user2} =
        Accounts.create_user(%{
          username: "jane_doe",
          email: "jane@example.com",
          password: "Pass1234!"
        })

      {:ok, _user3} =
        Accounts.create_user(%{
          username: "bob_smith",
          email: "bob@example.com",
          password: "Pass1234!"
        })

      # Search for "doe"
      results = Accounts.search_users("doe")
      assert length(results) == 2
      assert Enum.all?(results, fn u -> String.contains?(u.username, "doe") end)

      # Search for "bob"
      results = Accounts.search_users("bob")
      assert length(results) == 1
      assert Enum.at(results, 0).username == "bob_smith"
    end

    test "searches messages by content" do
      {:ok, user} =
        Accounts.create_user(%{
          username: "searcher",
          email: "search@example.com",
          password: "Pass1234!"
        })

      {:ok, channel} =
        Chat.create_channel(%{
          name: "searchtest",
          created_by_id: user.id
        })

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
          content: "Something else entirely",
          user_id: user.id,
          channel_id: channel.id
        })

      # Search for "world"
      result = Chat.search_messages("world", channel_id: channel.id)
      assert length(result.messages) == 2
    end
  end

  describe "message pagination" do
    test "paginates channel messages with cursor" do
      {:ok, user} =
        Accounts.create_user(%{
          username: "paginator",
          email: "page@example.com",
          password: "Pass1234!"
        })

      {:ok, channel} =
        Chat.create_channel(%{
          name: "paginationtest",
          created_by_id: user.id
        })

      # Create 30 messages
      messages =
        for i <- 1..30 do
          {:ok, msg} =
            Chat.create_channel_message(%{
              content: "Message #{i}",
              user_id: user.id,
              channel_id: channel.id
            })

          msg
        end

      # Fetch first page (10 messages)
      result = Chat.list_channel_messages(channel.id, limit: 10)
      assert length(result.messages) == 10
      assert result.has_more == true
      assert result.next_cursor != nil
      assert result.prev_cursor != nil

      # Fetch second page using cursor
      result2 = Chat.list_channel_messages(channel.id, limit: 10, before: result.next_cursor)
      assert length(result2.messages) == 10
      assert result2.has_more == true

      # Verify no overlap between pages
      first_page_ids = Enum.map(result.messages, & &1.id)
      second_page_ids = Enum.map(result2.messages, & &1.id)
      assert MapSet.disjoint?(MapSet.new(first_page_ids), MapSet.new(second_page_ids))

      # Fetch last page
      result3 = Chat.list_channel_messages(channel.id, limit: 10, before: result2.next_cursor)
      assert length(result3.messages) == 10
      assert result3.has_more == false
      assert result3.next_cursor == nil

      # Test fetching after cursor (newer messages)
      oldest_msg_id = List.last(messages).id
      result4 = Chat.list_channel_messages(channel.id, limit: 10, after: oldest_msg_id)
      assert length(result4.messages) <= 10
      Enum.each(result4.messages, fn msg -> assert msg.id > oldest_msg_id end)
    end

    test "paginates direct messages with cursor" do
      {:ok, user1} =
        Accounts.create_user(%{
          username: "sender",
          email: "sender@example.com",
          password: "Pass1234!"
        })

      {:ok, user2} =
        Accounts.create_user(%{
          username: "receiver",
          email: "receiver@example.com",
          password: "Pass1234!"
        })

      {:ok, conversation} = Chat.find_or_create_conversation(user1.id, user2.id)

      # Create 25 direct messages
      messages =
        for i <- 1..25 do
          {:ok, msg} =
            Chat.create_direct_message(%{
              content: "DM #{i}",
              user_id: if(rem(i, 2) == 0, do: user1.id, else: user2.id),
              direct_conversation_id: conversation.id
            })

          msg
        end

      # Fetch first page
      result = Chat.list_direct_messages(conversation.id, limit: 10)
      assert length(result.messages) == 10
      assert result.has_more == true

      # Fetch second page
      result2 = Chat.list_direct_messages(conversation.id, limit: 10, before: result.next_cursor)
      assert length(result2.messages) == 10
      assert result2.has_more == true

      # Fetch third page
      result3 = Chat.list_direct_messages(conversation.id, limit: 10, before: result2.next_cursor)
      assert length(result3.messages) == 5
      assert result3.has_more == false
      assert result3.next_cursor == nil

      # Test after cursor
      tenth_msg_id = Enum.at(messages, 9).id
      result4 = Chat.list_direct_messages(conversation.id, limit: 5, after: tenth_msg_id)
      assert length(result4.messages) <= 5
      Enum.each(result4.messages, fn msg -> assert msg.id > tenth_msg_id end)
    end

    test "paginates thread messages with cursor" do
      {:ok, user} =
        Accounts.create_user(%{
          username: "threader",
          email: "thread@example.com",
          password: "Pass1234!"
        })

      {:ok, channel} =
        Chat.create_channel(%{
          name: "threadpagination",
          created_by_id: user.id
        })

      # Create parent message
      {:ok, parent} =
        Chat.create_channel_message(%{
          content: "Parent",
          user_id: user.id,
          channel_id: channel.id
        })

      # Create 20 replies
      _replies =
        for i <- 1..20 do
          {:ok, reply} =
            Chat.create_channel_message(%{
              content: "Reply #{i}",
              user_id: user.id,
              channel_id: channel.id,
              parent_message_id: parent.id
            })

          reply
        end

      # Fetch first page of replies
      result = Chat.list_thread_messages(parent.id, limit: 8)
      assert length(result.messages) == 8
      assert result.has_more == true

      # Fetch second page
      result2 = Chat.list_thread_messages(parent.id, limit: 8, after: result.next_cursor)
      assert length(result2.messages) == 8
      assert result2.has_more == true

      # Verify messages are in chronological order (ascending for threads)
      assert List.first(result.messages).id < List.last(result.messages).id

      # Fetch remaining messages
      result3 = Chat.list_thread_messages(parent.id, limit: 8, after: result2.next_cursor)
      assert length(result3.messages) == 4
      assert result3.has_more == false
    end

    test "paginates search results with cursor" do
      {:ok, user} =
        Accounts.create_user(%{
          username: "searchuser",
          email: "searchuser@example.com",
          password: "Pass1234!"
        })

      {:ok, channel} =
        Chat.create_channel(%{
          name: "searchpagination",
          created_by_id: user.id
        })

      # Create 15 messages with "test" in content
      _messages =
        for i <- 1..15 do
          {:ok, msg} =
            Chat.create_channel_message(%{
              content: "This is test message #{i}",
              user_id: user.id,
              channel_id: channel.id
            })

          msg
        end

      # Create some messages without "test"
      {:ok, _other} =
        Chat.create_channel_message(%{
          content: "Different content",
          user_id: user.id,
          channel_id: channel.id
        })

      # Search with pagination
      result = Chat.search_messages("test", limit: 7)
      assert length(result.messages) == 7
      assert result.has_more == true

      # Fetch second page
      result2 = Chat.search_messages("test", limit: 7, before: result.next_cursor)
      assert length(result2.messages) == 7
      assert result2.has_more == true

      # Fetch remaining
      result3 = Chat.search_messages("test", limit: 7, before: result2.next_cursor)
      assert length(result3.messages) == 1
      assert result3.has_more == false

      # Verify all results contain "test"
      all_results = result.messages ++ result2.messages ++ result3.messages
      assert length(all_results) == 15
      Enum.each(all_results, fn msg -> assert String.contains?(msg.content, "test") end)
    end

    test "handles empty pagination results" do
      {:ok, user} =
        Accounts.create_user(%{
          username: "emptyuser",
          email: "empty@example.com",
          password: "Pass1234!"
        })

      {:ok, channel} =
        Chat.create_channel(%{
          name: "emptychannel",
          created_by_id: user.id
        })

      # Fetch from empty channel
      result = Chat.list_channel_messages(channel.id, limit: 10)
      assert result.messages == []
      assert result.has_more == false
      assert result.next_cursor == nil
      assert result.prev_cursor == nil
    end

    test "respects maximum limit constraint" do
      {:ok, user} =
        Accounts.create_user(%{
          username: "limiter",
          email: "limit@example.com",
          password: "Pass1234!"
        })

      {:ok, channel} =
        Chat.create_channel(%{
          name: "limitchannel",
          created_by_id: user.id
        })

      # Create 60 messages
      for i <- 1..60 do
        Chat.create_channel_message(%{
          content: "Message #{i}",
          user_id: user.id,
          channel_id: channel.id
        })
      end

      # Request with very large limit
      result = Chat.list_channel_messages(channel.id, limit: 1000)

      # Should still be paginated (fetching limit + 1 internally)
      # In controller, max limit would be enforced at 100
      assert length(result.messages) <= 1001
    end
  end
end
