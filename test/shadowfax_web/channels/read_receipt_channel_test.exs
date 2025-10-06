defmodule ShadowfaxWeb.ReadReceiptChannelTest do
  use ShadowfaxWeb.ChannelCase

  alias ShadowfaxWeb.UserSocket
  alias Shadowfax.{Accounts, Chat}

  setup do
    # Create test users
    {:ok, alice} =
      Accounts.create_user(%{
        username: "alice_rr",
        email: "alice_rr@example.com",
        password: "Password123!",
        first_name: "Alice",
        last_name: "ReadReceipt"
      })

    {:ok, bob} =
      Accounts.create_user(%{
        username: "bob_rr",
        email: "bob_rr@example.com",
        password: "Password123!",
        first_name: "Bob",
        last_name: "ReadReceipt"
      })

    # Create a test channel
    {:ok, channel} =
      Chat.create_channel(%{
        name: "read-receipt-test",
        description: "Channel for read receipt testing",
        is_private: false,
        created_by_id: alice.id
      })

    # Add bob to the channel
    {:ok, _} = Chat.add_user_to_channel(channel.id, bob.id, "member")

    # Create a conversation
    {:ok, conversation} = Chat.find_or_create_conversation(alice.id, bob.id)

    %{alice: alice, bob: bob, channel: channel, conversation: conversation}
  end

  describe "ChatChannel read receipts" do
    test "marks message as read and broadcasts read receipt", %{
      alice: alice,
      bob: bob,
      channel: channel
    } do
      # Connect Alice
      alice_token = Phoenix.Token.sign(ShadowfaxWeb.Endpoint, "user auth", alice.id)
      {:ok, socket} = connect(UserSocket, %{"token" => alice_token})
      {:ok, _response, _alice_socket} = subscribe_and_join(socket, "chat:#{channel.id}", %{})

      # Connect Bob
      bob_token = Phoenix.Token.sign(ShadowfaxWeb.Endpoint, "user auth", bob.id)
      {:ok, bob_socket} = connect(UserSocket, %{"token" => bob_token})
      {:ok, _response, bob_socket} = subscribe_and_join(bob_socket, "chat:#{channel.id}", %{})

      # Alice sends a message
      {:ok, message} =
        Chat.create_channel_message(%{
          content: "Hello Bob!",
          user_id: alice.id,
          channel_id: channel.id
        })

      # Bob marks the message as read
      ref = push(bob_socket, "mark_as_read", %{"message_id" => message.id})
      assert_reply ref, :ok, %{}

      # Alice should receive a read_receipt broadcast
      assert_broadcast "read_receipt", %{
        user_id: user_id,
        message_id: msg_id
      }

      assert user_id == bob.id
      assert msg_id == message.id

      # Verify read receipt was stored
      receipt = Chat.get_channel_read_receipt(bob.id, channel.id)
      assert receipt != nil
      assert receipt.last_read_message_id == message.id
    end

    test "sends last_read on join when receipt exists", %{
      alice: alice,
      bob: bob,
      channel: channel
    } do
      # Bob sends a message
      {:ok, message} =
        Chat.create_channel_message(%{
          content: "Test message",
          user_id: bob.id,
          channel_id: channel.id
        })

      # Alice marks it as read
      Chat.mark_channel_message_as_read(channel.id, alice.id, message.id)

      # Alice reconnects
      alice_token = Phoenix.Token.sign(ShadowfaxWeb.Endpoint, "user auth", alice.id)
      {:ok, alice_socket} = connect(UserSocket, %{"token" => alice_token})
      {:ok, _response, _socket} = subscribe_and_join(alice_socket, "chat:#{channel.id}", %{})

      # Should receive last_read push
      assert_push "last_read", %{message_id: msg_id}
      assert msg_id == message.id
    end

    test "does not send last_read when no receipt exists", %{alice: alice, channel: channel} do
      alice_token = Phoenix.Token.sign(ShadowfaxWeb.Endpoint, "user auth", alice.id)
      {:ok, alice_socket} = connect(UserSocket, %{"token" => alice_token})
      {:ok, _response, _socket} = subscribe_and_join(alice_socket, "chat:#{channel.id}", %{})

      # Should not receive last_read push
      refute_push "last_read", %{}
    end

    test "updates existing read receipt when marking newer message as read", %{
      alice: alice,
      bob: bob,
      channel: channel
    } do
      # Connect Bob
      bob_token = Phoenix.Token.sign(ShadowfaxWeb.Endpoint, "user auth", bob.id)
      {:ok, bob_socket} = connect(UserSocket, %{"token" => bob_token})
      {:ok, _response, bob_socket} = subscribe_and_join(bob_socket, "chat:#{channel.id}", %{})

      # Alice sends two messages
      {:ok, message1} =
        Chat.create_channel_message(%{
          content: "Message 1",
          user_id: alice.id,
          channel_id: channel.id
        })

      {:ok, message2} =
        Chat.create_channel_message(%{
          content: "Message 2",
          user_id: alice.id,
          channel_id: channel.id
        })

      # Bob marks first message as read
      ref1 = push(bob_socket, "mark_as_read", %{"message_id" => message1.id})
      assert_reply ref1, :ok, %{}

      # Bob marks second message as read
      ref2 = push(bob_socket, "mark_as_read", %{"message_id" => message2.id})
      assert_reply ref2, :ok, %{}

      # Verify latest read receipt
      receipt = Chat.get_channel_read_receipt(bob.id, channel.id)
      assert receipt.last_read_message_id == message2.id
    end
  end

  describe "ConversationChannel read receipts" do
    test "marks message as read and broadcasts read receipt", %{
      alice: alice,
      bob: bob,
      conversation: conversation
    } do
      # Connect Alice
      alice_token = Phoenix.Token.sign(ShadowfaxWeb.Endpoint, "user auth", alice.id)
      {:ok, socket} = connect(UserSocket, %{"token" => alice_token})

      {:ok, _response, _alice_socket} =
        subscribe_and_join(socket, "conversation:#{conversation.id}", %{})

      # Connect Bob
      bob_token = Phoenix.Token.sign(ShadowfaxWeb.Endpoint, "user auth", bob.id)
      {:ok, bob_socket} = connect(UserSocket, %{"token" => bob_token})

      {:ok, _response, bob_socket} =
        subscribe_and_join(bob_socket, "conversation:#{conversation.id}", %{})

      # Alice sends a DM
      {:ok, message} =
        Chat.create_direct_message(%{
          content: "Hello Bob DM!",
          user_id: alice.id,
          direct_conversation_id: conversation.id
        })

      # Bob marks the message as read
      ref = push(bob_socket, "mark_as_read", %{"message_id" => message.id})
      assert_reply ref, :ok, %{}

      # Alice should receive a read_receipt broadcast
      assert_broadcast "read_receipt", %{
        user_id: user_id,
        message_id: msg_id
      }

      assert user_id == bob.id
      assert msg_id == message.id

      # Verify read receipt was stored
      receipt = Chat.get_conversation_read_receipt(bob.id, conversation.id)
      assert receipt != nil
      assert receipt.last_read_message_id == message.id
    end

    test "sends last_read on join when receipt exists", %{
      alice: alice,
      bob: bob,
      conversation: conversation
    } do
      # Bob sends a message
      {:ok, message} =
        Chat.create_direct_message(%{
          content: "DM test",
          user_id: bob.id,
          direct_conversation_id: conversation.id
        })

      # Alice marks it as read
      Chat.mark_conversation_message_as_read(conversation.id, alice.id, message.id)

      # Alice reconnects
      alice_token = Phoenix.Token.sign(ShadowfaxWeb.Endpoint, "user auth", alice.id)
      {:ok, alice_socket} = connect(UserSocket, %{"token" => alice_token})

      {:ok, _response, _socket} =
        subscribe_and_join(alice_socket, "conversation:#{conversation.id}", %{})

      # Should receive last_read push
      assert_push "last_read", %{message_id: msg_id}
      assert msg_id == message.id
    end

    test "does not send last_read when no receipt exists", %{
      alice: alice,
      conversation: conversation
    } do
      alice_token = Phoenix.Token.sign(ShadowfaxWeb.Endpoint, "user auth", alice.id)
      {:ok, alice_socket} = connect(UserSocket, %{"token" => alice_token})

      {:ok, _response, _socket} =
        subscribe_and_join(alice_socket, "conversation:#{conversation.id}", %{})

      # Should not receive last_read push
      refute_push "last_read", %{}
    end

    test "handles read receipts for both users independently", %{
      alice: alice,
      bob: bob,
      conversation: conversation
    } do
      # Connect both users
      alice_token = Phoenix.Token.sign(ShadowfaxWeb.Endpoint, "user auth", alice.id)
      {:ok, alice_socket} = connect(UserSocket, %{"token" => alice_token})

      {:ok, _response, alice_socket} =
        subscribe_and_join(alice_socket, "conversation:#{conversation.id}", %{})

      bob_token = Phoenix.Token.sign(ShadowfaxWeb.Endpoint, "user auth", bob.id)
      {:ok, bob_socket} = connect(UserSocket, %{"token" => bob_token})

      {:ok, _response, bob_socket} =
        subscribe_and_join(bob_socket, "conversation:#{conversation.id}", %{})

      # Alice sends message 1
      {:ok, message1} =
        Chat.create_direct_message(%{
          content: "Message from Alice",
          user_id: alice.id,
          direct_conversation_id: conversation.id
        })

      # Bob sends message 2
      {:ok, message2} =
        Chat.create_direct_message(%{
          content: "Message from Bob",
          user_id: bob.id,
          direct_conversation_id: conversation.id
        })

      # Bob marks Alice's message as read
      ref1 = push(bob_socket, "mark_as_read", %{"message_id" => message1.id})
      assert_reply ref1, :ok, %{}

      # Alice marks Bob's message as read
      ref2 = push(alice_socket, "mark_as_read", %{"message_id" => message2.id})
      assert_reply ref2, :ok, %{}

      # Verify independent read receipts
      bob_receipt = Chat.get_conversation_read_receipt(bob.id, conversation.id)
      alice_receipt = Chat.get_conversation_read_receipt(alice.id, conversation.id)

      assert bob_receipt.last_read_message_id == message1.id
      assert alice_receipt.last_read_message_id == message2.id
    end
  end

  describe "read receipt error handling" do
    test "returns error when marking non-existent message", %{bob: bob, channel: channel} do
      bob_token = Phoenix.Token.sign(ShadowfaxWeb.Endpoint, "user auth", bob.id)
      {:ok, bob_socket} = connect(UserSocket, %{"token" => bob_token})
      {:ok, _response, bob_socket} = subscribe_and_join(bob_socket, "chat:#{channel.id}", %{})

      # Try to mark non-existent message as read
      ref = push(bob_socket, "mark_as_read", %{"message_id" => 999_999})
      assert_reply ref, :error, _error_response
    end

    test "prevents marking messages in wrong channel", %{alice: alice, bob: bob} do
      # Create a different channel
      {:ok, other_channel} =
        Chat.create_channel(%{
          name: "other-channel",
          created_by_id: alice.id
        })

      {:ok, _} = Chat.add_user_to_channel(other_channel.id, bob.id)

      # Bob joins first channel
      bob_token = Phoenix.Token.sign(ShadowfaxWeb.Endpoint, "user auth", bob.id)
      {:ok, bob_socket} = connect(UserSocket, %{"token" => bob_token})

      {:ok, first_channel} =
        Chat.create_channel(%{
          name: "first-channel",
          created_by_id: alice.id
        })

      {:ok, _} = Chat.add_user_to_channel(first_channel.id, bob.id)

      {:ok, _response, bob_socket} =
        subscribe_and_join(bob_socket, "chat:#{first_channel.id}", %{})

      # Create message in other channel
      {:ok, message} =
        Chat.create_channel_message(%{
          content: "Message in other channel",
          user_id: alice.id,
          channel_id: other_channel.id
        })

      # Try to mark it as read from first channel socket
      ref = push(bob_socket, "mark_as_read", %{"message_id" => message.id})
      assert_reply ref, :error, _error_response
    end
  end
end
