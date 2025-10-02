defmodule ShadowfaxWeb.MessageControllerTest do
  use ShadowfaxWeb.ConnCase, async: true

  alias Shadowfax.{Accounts, Chat}

  setup do
    # Create test users
    {:ok, user1} =
      Accounts.create_user(%{
        username: "user1",
        email: "user1@example.com",
        password: "Password123!",
        first_name: "User",
        last_name: "One"
      })

    {:ok, user2} =
      Accounts.create_user(%{
        username: "user2",
        email: "user2@example.com",
        password: "Password123!",
        first_name: "User",
        last_name: "Two"
      })

    # Create a public channel
    {:ok, channel} =
      Chat.create_channel(%{
        name: "test-channel",
        description: "Test channel",
        created_by_id: user1.id,
        is_private: false
      })

    # Create a direct conversation
    {:ok, conversation} = Chat.find_or_create_conversation(user1.id, user2.id)

    # Generate tokens
    token1 = Phoenix.Token.sign(ShadowfaxWeb.Endpoint, "user auth", user1.id)
    token2 = Phoenix.Token.sign(ShadowfaxWeb.Endpoint, "user auth", user2.id)

    {:ok,
     user1: user1,
     user2: user2,
     channel: channel,
     conversation: conversation,
     token1: token1,
     token2: token2}
  end

  describe "POST /api/channels/:id/messages" do
    test "creates channel message with authenticated user", %{
      conn: conn,
      user1: user1,
      channel: channel,
      token1: token1
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token1}")
        |> post(~p"/api/channels/#{channel.id}/messages", %{
          message: %{content: "Hello channel!"}
        })

      assert %{
               "success" => true,
               "data" => %{
                 "message" => message
               }
             } = json_response(conn, 201)

      assert message["content"] == "Hello channel!"
      assert message["user"]["id"] == user1.id
      assert message["channel_id"] == channel.id
    end

    test "enforces user_id from token, ignores user_id in payload", %{
      conn: conn,
      user1: user1,
      user2: user2,
      channel: channel,
      token1: token1
    } do
      # Try to send message as user2 while authenticated as user1
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token1}")
        |> post(~p"/api/channels/#{channel.id}/messages", %{
          message: %{
            content: "Attempting to spoof user",
            # This should be ignored
            user_id: user2.id
          }
        })

      assert %{
               "success" => true,
               "data" => %{
                 "message" => message
               }
             } = json_response(conn, 201)

      # Message should be from user1, not user2
      assert message["user"]["id"] == user1.id
      refute message["user"]["id"] == user2.id
    end

    test "rejects request without authentication", %{conn: conn, channel: channel} do
      conn =
        post(conn, ~p"/api/channels/#{channel.id}/messages", %{
          message: %{content: "Unauthenticated message"}
        })

      assert %{
               "success" => false,
               "error" => "Authentication required"
             } = json_response(conn, 401)
    end

    test "rejects message to private channel when not a member", %{
      conn: conn,
      user1: user1,
      token2: token2
    } do
      # Create a private channel owned by user1
      {:ok, private_channel} =
        Chat.create_channel(%{
          name: "private-channel",
          description: "Private",
          created_by_id: user1.id,
          is_private: true
        })

      # Try to send message as user2 (not a member)
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token2}")
        |> post(~p"/api/channels/#{private_channel.id}/messages", %{
          message: %{content: "Unauthorized message"}
        })

      assert %{
               "success" => false,
               "error" => "Access denied. You must be a member of this channel."
             } = json_response(conn, 403)
    end
  end

  describe "POST /api/conversations/:id/messages" do
    test "creates direct message with authenticated user", %{
      conn: conn,
      user1: user1,
      conversation: conversation,
      token1: token1
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token1}")
        |> post(~p"/api/conversations/#{conversation.id}/messages", %{
          message: %{content: "Direct message!"}
        })

      assert %{
               "success" => true,
               "data" => %{
                 "message" => message
               }
             } = json_response(conn, 201)

      assert message["content"] == "Direct message!"
      assert message["user"]["id"] == user1.id
      assert message["direct_conversation_id"] == conversation.id
    end

    test "enforces user_id from token for direct messages", %{
      conn: conn,
      user1: user1,
      user2: user2,
      conversation: conversation,
      token1: token1
    } do
      # Try to spoof user_id
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token1}")
        |> post(~p"/api/conversations/#{conversation.id}/messages", %{
          message: %{
            content: "Spoofed direct message",
            user_id: user2.id
          }
        })

      assert %{
               "success" => true,
               "data" => %{
                 "message" => message
               }
             } = json_response(conn, 201)

      # Should be from user1, not user2
      assert message["user"]["id"] == user1.id
    end

    test "rejects direct message without authentication", %{
      conn: conn,
      conversation: conversation
    } do
      conn =
        post(conn, ~p"/api/conversations/#{conversation.id}/messages", %{
          message: %{content: "Unauthenticated DM"}
        })

      assert %{
               "success" => false,
               "error" => "Authentication required"
             } = json_response(conn, 401)
    end

    test "rejects direct message to conversation user is not part of", %{
      conn: conn,
      user1: user1,
      user2: user2
    } do
      # Create a third user
      {:ok, user3} =
        Accounts.create_user(%{
          username: "user3",
          email: "user3@example.com",
          password: "Password123!",
          first_name: "User",
          last_name: "Three"
        })

      # Create conversation between user1 and user2
      {:ok, conv} = Chat.find_or_create_conversation(user1.id, user2.id)

      # Try to send message as user3 (not part of conversation)
      token3 = Phoenix.Token.sign(ShadowfaxWeb.Endpoint, "user auth", user3.id)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token3}")
        |> post(~p"/api/conversations/#{conv.id}/messages", %{
          message: %{content: "Unauthorized DM"}
        })

      assert %{
               "success" => false,
               "error" => "Access denied"
             } = json_response(conn, 403)
    end
  end

  describe "PUT /api/messages/:id (update message)" do
    test "allows user to edit their own message", %{
      conn: conn,
      user1: user1,
      channel: channel,
      token1: token1
    } do
      # Create message
      {:ok, message} =
        Chat.create_channel_message(%{
          content: "Original message",
          user_id: user1.id,
          channel_id: channel.id
        })

      # Edit message
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token1}")
        |> put(~p"/api/messages/#{message.id}", %{
          message: %{content: "Edited message"}
        })

      assert %{
               "success" => true,
               "data" => %{
                 "message" => updated_message
               }
             } = json_response(conn, 200)

      assert updated_message["content"] == "Edited message"
      assert updated_message["edited_at"] != nil
    end

    test "prevents user from editing another user's message", %{
      conn: conn,
      user1: user1,
      channel: channel,
      token2: token2
    } do
      # Create message as user1
      {:ok, message} =
        Chat.create_channel_message(%{
          content: "User1's message",
          user_id: user1.id,
          channel_id: channel.id
        })

      # Try to edit as user2
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token2}")
        |> put(~p"/api/messages/#{message.id}", %{
          message: %{content: "Hacked content"}
        })

      assert %{
               "success" => false,
               "error" => "You can only edit your own messages within 15 minutes"
             } = json_response(conn, 403)
    end

    test "requires authentication to edit message", %{conn: conn, user1: user1, channel: channel} do
      {:ok, message} =
        Chat.create_channel_message(%{
          content: "Message",
          user_id: user1.id,
          channel_id: channel.id
        })

      conn =
        put(conn, ~p"/api/messages/#{message.id}", %{
          message: %{content: "Edited"}
        })

      assert %{
               "success" => false,
               "error" => "Authentication required"
             } = json_response(conn, 401)
    end
  end

  describe "DELETE /api/messages/:id" do
    test "allows user to delete their own message", %{
      conn: conn,
      user1: user1,
      channel: channel,
      token1: token1
    } do
      {:ok, message} =
        Chat.create_channel_message(%{
          content: "To be deleted",
          user_id: user1.id,
          channel_id: channel.id
        })

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token1}")
        |> delete(~p"/api/messages/#{message.id}")

      assert %{
               "success" => true,
               "message" => "Message deleted successfully"
             } = json_response(conn, 200)
    end

    test "prevents user from deleting another user's message", %{
      conn: conn,
      user1: user1,
      channel: channel,
      token2: token2
    } do
      {:ok, message} =
        Chat.create_channel_message(%{
          content: "User1's message",
          user_id: user1.id,
          channel_id: channel.id
        })

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token2}")
        |> delete(~p"/api/messages/#{message.id}")

      assert %{
               "success" => false,
               "error" =>
                 "You can only delete your own messages or you need admin/owner privileges"
             } = json_response(conn, 403)
    end

    test "requires authentication to delete message", %{
      conn: conn,
      user1: user1,
      channel: channel
    } do
      {:ok, message} =
        Chat.create_channel_message(%{
          content: "Message",
          user_id: user1.id,
          channel_id: channel.id
        })

      conn = delete(conn, ~p"/api/messages/#{message.id}")

      assert %{
               "success" => false,
               "error" => "Authentication required"
             } = json_response(conn, 401)
    end
  end
end
