defmodule ShadowfaxWeb.PresenceTest do
  use ShadowfaxWeb.ChannelCase

  alias ShadowfaxWeb.{Presence, UserSocket}
  alias Shadowfax.Accounts

  setup do
    # Create test users
    {:ok, alice} =
      Accounts.create_user(%{
        username: "alice_presence",
        email: "alice_presence@example.com",
        password: "Password123!",
        first_name: "Alice",
        last_name: "Wonder"
      })

    {:ok, bob} =
      Accounts.create_user(%{
        username: "bob_presence",
        email: "bob_presence@example.com",
        password: "Password123!",
        first_name: "Bob",
        last_name: "Builder"
      })

    # Create a test channel (alice is automatically added as owner)
    {:ok, channel} =
      Shadowfax.Chat.create_channel(%{
        name: "presence-test",
        description: "Channel for presence testing",
        is_public: true,
        created_by_id: alice.id
      })

    # Add bob to the channel
    {:ok, _} = Shadowfax.Chat.add_user_to_channel(channel.id, bob.id, "member")

    %{alice: alice, bob: bob, channel: channel}
  end

  describe "ChatChannel presence tracking" do
    test "tracks user presence when joining channel", %{alice: alice, channel: channel} do
      # Generate auth token for Alice
      token = Phoenix.Token.sign(ShadowfaxWeb.Endpoint, "user auth", alice.id)

      # Connect socket with Alice's token
      {:ok, socket} = connect(UserSocket, %{"token" => token})

      # Join the channel
      {:ok, _response, socket} = subscribe_and_join(socket, "chat:#{channel.id}", %{})

      # Check presence list
      presences = Presence.list(socket)
      assert Map.has_key?(presences, "#{alice.id}")

      presence_data = presences["#{alice.id}"]
      assert presence_data.metas |> hd() |> Map.get(:user_id) == alice.id
      assert presence_data.metas |> hd() |> Map.get(:username) == alice.username
    end

    test "tracks multiple users in the same channel", %{
      alice: alice,
      bob: bob,
      channel: channel
    } do
      # Connect Alice
      alice_token = Phoenix.Token.sign(ShadowfaxWeb.Endpoint, "user auth", alice.id)
      {:ok, alice_socket} = connect(UserSocket, %{"token" => alice_token})
      {:ok, _response, alice_socket} = subscribe_and_join(alice_socket, "chat:#{channel.id}", %{})

      # Connect Bob
      bob_token = Phoenix.Token.sign(ShadowfaxWeb.Endpoint, "user auth", bob.id)
      {:ok, bob_socket} = connect(UserSocket, %{"token" => bob_token})
      {:ok, _response, _bob_socket} = subscribe_and_join(bob_socket, "chat:#{channel.id}", %{})

      # Check presence list from Alice's perspective
      presences = Presence.list(alice_socket)
      assert map_size(presences) == 2
      assert Map.has_key?(presences, "#{alice.id}")
      assert Map.has_key?(presences, "#{bob.id}")
    end

    test "sends presence_state on join", %{alice: alice, channel: channel} do
      alice_token = Phoenix.Token.sign(ShadowfaxWeb.Endpoint, "user auth", alice.id)
      {:ok, alice_socket} = connect(UserSocket, %{"token" => alice_token})

      {:ok, _response, _socket} = subscribe_and_join(alice_socket, "chat:#{channel.id}", %{})

      # Check that presence_state is pushed
      assert_push "presence_state", presence_state
      assert is_map(presence_state)
    end

    test "includes user metadata in presence", %{alice: alice, channel: channel} do
      alice_token = Phoenix.Token.sign(ShadowfaxWeb.Endpoint, "user auth", alice.id)
      {:ok, alice_socket} = connect(UserSocket, %{"token" => alice_token})
      {:ok, _response, alice_socket} = subscribe_and_join(alice_socket, "chat:#{channel.id}", %{})

      presences = Presence.list(alice_socket)
      alice_presence = presences["#{alice.id}"]
      meta = alice_presence.metas |> hd()

      assert meta.user_id == alice.id
      assert meta.username == alice.username
      assert meta.first_name == alice.first_name
      assert meta.last_name == alice.last_name
      assert meta.status == alice.status
      assert Map.has_key?(meta, :online_at)
    end
  end

  describe "ConversationChannel presence tracking" do
    test "tracks user presence in direct conversations", %{alice: alice, bob: bob} do
      # Create a conversation between Alice and Bob
      {:ok, conversation} =
        Shadowfax.Chat.find_or_create_conversation(alice.id, bob.id)

      # Connect Alice
      alice_token = Phoenix.Token.sign(ShadowfaxWeb.Endpoint, "user auth", alice.id)
      {:ok, alice_socket} = connect(UserSocket, %{"token" => alice_token})

      {:ok, _response, alice_socket} =
        subscribe_and_join(alice_socket, "conversation:#{conversation.id}", %{})

      # Check presence
      presences = Presence.list(alice_socket)
      assert Map.has_key?(presences, "#{alice.id}")
    end

    test "both users appear online when joined to conversation", %{alice: alice, bob: bob} do
      {:ok, conversation} =
        Shadowfax.Chat.find_or_create_conversation(alice.id, bob.id)

      # Connect both users
      alice_token = Phoenix.Token.sign(ShadowfaxWeb.Endpoint, "user auth", alice.id)
      {:ok, alice_socket} = connect(UserSocket, %{"token" => alice_token})

      {:ok, _response, alice_socket} =
        subscribe_and_join(alice_socket, "conversation:#{conversation.id}", %{})

      bob_token = Phoenix.Token.sign(ShadowfaxWeb.Endpoint, "user auth", bob.id)
      {:ok, bob_socket} = connect(UserSocket, %{"token" => bob_token})

      {:ok, _response, _bob_socket} =
        subscribe_and_join(bob_socket, "conversation:#{conversation.id}", %{})

      # Check from Alice's perspective
      presences = Presence.list(alice_socket)
      assert map_size(presences) == 2
      assert Map.has_key?(presences, "#{alice.id}")
      assert Map.has_key?(presences, "#{bob.id}")
    end
  end

  describe "Presence.list/1" do
    test "returns empty map when no users are present" do
      presences = Presence.list("chat:nonexistent")
      assert presences == %{}
    end

    test "can query presence by topic string", %{alice: alice, channel: channel} do
      alice_token = Phoenix.Token.sign(ShadowfaxWeb.Endpoint, "user auth", alice.id)
      {:ok, alice_socket} = connect(UserSocket, %{"token" => alice_token})
      {:ok, _response, _socket} = subscribe_and_join(alice_socket, "chat:#{channel.id}", %{})

      # Query by topic string
      presences = Presence.list("chat:#{channel.id}")
      assert Map.has_key?(presences, "#{alice.id}")
    end
  end
end
