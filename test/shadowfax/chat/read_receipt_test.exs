defmodule Shadowfax.Chat.ReadReceiptTest do
  use Shadowfax.DataCase, async: true

  alias Shadowfax.Accounts
  alias Shadowfax.Chat
  alias Shadowfax.Chat.ReadReceipt
  alias Shadowfax.Repo

  setup do
    # Clear the database
    Repo.delete_all(ReadReceipt)
    Repo.delete_all(Shadowfax.Chat.Message)
    Repo.delete_all(Shadowfax.Chat.ChannelMembership)
    Repo.delete_all(Shadowfax.Chat.DirectConversation)
    Repo.delete_all(Shadowfax.Chat.Channel)
    Repo.delete_all(Shadowfax.Accounts.User)

    # Create test users
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

    # Create a test channel
    {:ok, channel} =
      Chat.create_channel(%{
        name: "testchannel",
        created_by_id: user1.id
      })

    # Add user2 to the channel
    {:ok, _membership} = Chat.add_user_to_channel(channel.id, user2.id)

    # Create a conversation
    {:ok, conversation} = Chat.find_or_create_conversation(user1.id, user2.id)

    {:ok, user1: user1, user2: user2, channel: channel, conversation: conversation}
  end

  describe "channel_changeset/2" do
    test "valid channel read receipt", %{user1: user1, channel: channel} do
      # Create a real message first
      {:ok, message} =
        Chat.create_channel_message(%{
          content: "Test",
          user_id: user1.id,
          channel_id: channel.id
        })

      attrs = %{
        user_id: user1.id,
        channel_id: channel.id,
        last_read_message_id: message.id
      }

      changeset = ReadReceipt.channel_changeset(%ReadReceipt{}, attrs)
      assert changeset.valid?
    end

    test "requires user_id, channel_id, and last_read_message_id", %{channel: channel} do
      attrs = %{channel_id: channel.id}
      changeset = ReadReceipt.channel_changeset(%ReadReceipt{}, attrs)
      refute changeset.valid?
      assert %{user_id: _, last_read_message_id: _} = errors_on(changeset)
    end

    test "rejects conversation_id when channel_id is present", %{
      user1: user1,
      channel: channel,
      conversation: conversation
    } do
      # Create a real message
      {:ok, message} =
        Chat.create_channel_message(%{
          content: "Test",
          user_id: user1.id,
          channel_id: channel.id
        })

      # Manually set both to test validation (bypassing cast)
      changeset =
        %ReadReceipt{}
        |> Ecto.Changeset.change(%{
          user_id: user1.id,
          channel_id: channel.id,
          direct_conversation_id: conversation.id,
          last_read_message_id: message.id
        })
        |> ReadReceipt.channel_changeset(%{})

      refute changeset.valid?
      assert %{channel_id: _} = errors_on(changeset)
    end
  end

  describe "conversation_changeset/2" do
    test "valid conversation read receipt", %{user1: user1, conversation: conversation} do
      # Create a real message first
      {:ok, message} =
        Chat.create_direct_message(%{
          content: "Test DM",
          user_id: user1.id,
          direct_conversation_id: conversation.id
        })

      attrs = %{
        user_id: user1.id,
        direct_conversation_id: conversation.id,
        last_read_message_id: message.id
      }

      changeset = ReadReceipt.conversation_changeset(%ReadReceipt{}, attrs)
      assert changeset.valid?
    end

    test "requires user_id, direct_conversation_id, and last_read_message_id",
         %{conversation: conversation} do
      attrs = %{direct_conversation_id: conversation.id}
      changeset = ReadReceipt.conversation_changeset(%ReadReceipt{}, attrs)
      refute changeset.valid?
      assert %{user_id: _, last_read_message_id: _} = errors_on(changeset)
    end

    test "rejects channel_id when conversation_id is present", %{
      user1: user1,
      channel: channel,
      conversation: conversation
    } do
      # Create a real message
      {:ok, message} =
        Chat.create_direct_message(%{
          content: "Test DM",
          user_id: user1.id,
          direct_conversation_id: conversation.id
        })

      # Manually set both to test validation
      changeset =
        %ReadReceipt{}
        |> Ecto.Changeset.change(%{
          user_id: user1.id,
          channel_id: channel.id,
          direct_conversation_id: conversation.id,
          last_read_message_id: message.id
        })
        |> ReadReceipt.conversation_changeset(%{})

      refute changeset.valid?
      assert %{direct_conversation_id: _} = errors_on(changeset)
    end
  end

  describe "channel_read_receipt_query/2" do
    test "finds read receipt for user in channel", %{user1: user1, channel: channel} do
      # Create a real message first
      {:ok, message} =
        Chat.create_channel_message(%{
          content: "Test",
          user_id: user1.id,
          channel_id: channel.id
        })

      # Create a read receipt
      {:ok, receipt} =
        %ReadReceipt{}
        |> ReadReceipt.channel_changeset(%{
          user_id: user1.id,
          channel_id: channel.id,
          last_read_message_id: message.id
        })
        |> Repo.insert()

      found = ReadReceipt.channel_read_receipt_query(user1.id, channel.id) |> Repo.one()
      assert found.id == receipt.id
    end

    test "returns nil when no receipt exists", %{user1: user1, channel: channel} do
      found = ReadReceipt.channel_read_receipt_query(user1.id, channel.id) |> Repo.one()
      assert found == nil
    end
  end

  describe "conversation_read_receipt_query/2" do
    test "finds read receipt for user in conversation", %{
      user1: user1,
      conversation: conversation
    } do
      # Create a real message first
      {:ok, message} =
        Chat.create_direct_message(%{
          content: "Test DM",
          user_id: user1.id,
          direct_conversation_id: conversation.id
        })

      # Create a read receipt
      {:ok, receipt} =
        %ReadReceipt{}
        |> ReadReceipt.conversation_changeset(%{
          user_id: user1.id,
          direct_conversation_id: conversation.id,
          last_read_message_id: message.id
        })
        |> Repo.insert()

      found =
        ReadReceipt.conversation_read_receipt_query(user1.id, conversation.id) |> Repo.one()

      assert found.id == receipt.id
    end

    test "returns nil when no receipt exists", %{user1: user1, conversation: conversation} do
      found =
        ReadReceipt.conversation_read_receipt_query(user1.id, conversation.id) |> Repo.one()

      assert found == nil
    end
  end

  describe "unread_count_for_channel/2" do
    test "returns 0 when no messages exist", %{user1: user1, channel: channel} do
      count = ReadReceipt.unread_count_for_channel(user1.id, channel.id)
      assert count == 0
    end

    test "returns count of unread messages", %{user1: user1, user2: user2, channel: channel} do
      # User2 sends 3 messages
      {:ok, msg1} =
        Chat.create_channel_message(%{
          content: "Message 1",
          user_id: user2.id,
          channel_id: channel.id
        })

      {:ok, msg2} =
        Chat.create_channel_message(%{
          content: "Message 2",
          user_id: user2.id,
          channel_id: channel.id
        })

      {:ok, _msg3} =
        Chat.create_channel_message(%{
          content: "Message 3",
          user_id: user2.id,
          channel_id: channel.id
        })

      # User1 has read up to message 1
      Chat.mark_channel_message_as_read(channel.id, user1.id, msg1.id)

      # Should have 2 unread messages (msg2 and msg3)
      count = ReadReceipt.unread_count_for_channel(user1.id, channel.id)
      assert count == 2

      # After reading msg2 - use Chat context function
      Chat.mark_channel_message_as_read(channel.id, user1.id, msg2.id)

      # Should have 1 unread message
      count = ReadReceipt.unread_count_for_channel(user1.id, channel.id)
      assert count == 1
    end

    test "excludes own messages from unread count", %{user1: user1, channel: channel} do
      # User1 sends a message
      {:ok, _msg} =
        Chat.create_channel_message(%{
          content: "My message",
          user_id: user1.id,
          channel_id: channel.id
        })

      count = ReadReceipt.unread_count_for_channel(user1.id, channel.id)
      assert count == 0
    end
  end

  describe "unread_count_for_conversation/2" do
    test "returns 0 when no messages exist", %{user1: user1, conversation: conversation} do
      count = ReadReceipt.unread_count_for_conversation(user1.id, conversation.id)
      assert count == 0
    end

    test "returns count of unread messages", %{
      user1: user1,
      user2: user2,
      conversation: conversation
    } do
      # User2 sends 2 messages
      {:ok, msg1} =
        Chat.create_direct_message(%{
          content: "DM 1",
          user_id: user2.id,
          direct_conversation_id: conversation.id
        })

      {:ok, _msg2} =
        Chat.create_direct_message(%{
          content: "DM 2",
          user_id: user2.id,
          direct_conversation_id: conversation.id
        })

      # User1 has read up to message 1
      Chat.mark_conversation_message_as_read(conversation.id, user1.id, msg1.id)

      # Should have 1 unread message
      count = ReadReceipt.unread_count_for_conversation(user1.id, conversation.id)
      assert count == 1
    end
  end

  describe "get_last_read_message_id/2" do
    test "returns last read message ID for channel", %{user1: user1, channel: channel} do
      # Create a real message
      {:ok, message} =
        Chat.create_channel_message(%{
          content: "Test",
          user_id: user1.id,
          channel_id: channel.id
        })

      # Create a read receipt
      Chat.mark_channel_message_as_read(channel.id, user1.id, message.id)

      last_read = ReadReceipt.get_last_read_message_id(user1.id, channel.id)
      assert last_read == message.id
    end

    test "returns nil when no receipt exists", %{user1: user1, channel: channel} do
      last_read = ReadReceipt.get_last_read_message_id(user1.id, channel.id)
      assert last_read == nil
    end

    test "returns last read message ID for conversation", %{
      user1: user1,
      conversation: conversation
    } do
      # Create a real message
      {:ok, message} =
        Chat.create_direct_message(%{
          content: "Test DM",
          user_id: user1.id,
          direct_conversation_id: conversation.id
        })

      # Create a read receipt
      Chat.mark_conversation_message_as_read(conversation.id, user1.id, message.id)

      last_read = ReadReceipt.get_last_read_message_id(user1.id, {:conversation, conversation.id})
      assert last_read == message.id
    end
  end

  describe "user_read_receipts_query/1" do
    test "returns all read receipts for a user", %{
      user1: user1,
      channel: channel,
      conversation: conversation
    } do
      # Create real messages
      {:ok, channel_msg} =
        Chat.create_channel_message(%{
          content: "Channel msg",
          user_id: user1.id,
          channel_id: channel.id
        })

      {:ok, dm_msg} =
        Chat.create_direct_message(%{
          content: "DM",
          user_id: user1.id,
          direct_conversation_id: conversation.id
        })

      # Create read receipts for channel and conversation
      Chat.mark_channel_message_as_read(channel.id, user1.id, channel_msg.id)
      Chat.mark_conversation_message_as_read(conversation.id, user1.id, dm_msg.id)

      receipts = ReadReceipt.user_read_receipts_query(user1.id) |> Repo.all()
      assert length(receipts) == 2
    end
  end
end
