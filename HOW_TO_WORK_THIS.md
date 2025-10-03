# How to Work with Shadowfax Chat

This guide shows you how to interact with your chat application using the Elixir console (IEx).

## Table of Contents
- [Starting the Console](#starting-the-console)
- [Finding a User](#finding-a-user)
- [Viewing Channels](#viewing-channels)
- [Sending Messages to a Channel](#sending-messages-to-a-channel)
- [Sending Direct Messages](#sending-direct-messages)
- [Viewing Messages](#viewing-messages)
- [Advanced Operations](#advanced-operations)

---

## Starting the Console

Open your terminal and run:

```bash
iex -S mix
```

This starts an interactive Elixir shell with your application loaded.

---

## Finding a User

### Step 1: Get Alice's account

```elixir
# Get Alice by email
alice = Shadowfax.Accounts.get_user_by_email("alice@example.com")

# You should see:
# %Shadowfax.Accounts.User{
#   id: 1,
#   username: "alice",
#   email: "alice@example.com",
#   ...
# }
```

### Step 2: Verify Alice's ID

```elixir
alice.id
# => 1
```

---

## Viewing Channels

### List all public channels

```elixir
Shadowfax.Chat.list_public_channels()
```

### List channels Alice is a member of

```elixir
Shadowfax.Chat.list_user_channels(alice.id)
```

### Get a specific channel by name

```elixir
general = Shadowfax.Chat.get_channel_by_name("general")

# You should see:
# %Shadowfax.Chat.Channel{
#   id: 1,
#   name: "general",
#   description: "General discussion for everyone",
#   ...
# }
```

---

## Sending Messages to a Channel

### Step 1: Make sure you have the user and channel

```elixir
# Get Alice
alice = Shadowfax.Accounts.get_user_by_email("alice@example.com")

# Get the general channel
general = Shadowfax.Chat.get_channel_by_name("general")
```

### Step 2: Send a message

```elixir
{:ok, message} = Shadowfax.Chat.create_channel_message(%{
  content: "Hello from Alice! This is my first message.",
  user_id: alice.id,
  channel_id: general.id
})
```

### Step 3: Verify the message was created

```elixir
message.content
# => "Hello from Alice! This is my first message."

message.user_id
# => 1 (Alice's ID)

message.channel_id
# => 1 (General channel ID)
```

---

## Sending Direct Messages

### Step 1: Get both users

```elixir
alice = Shadowfax.Accounts.get_user_by_email("alice@example.com")
bob = Shadowfax.Accounts.get_user_by_email("bob@example.com")
```

### Step 2: Find or create a conversation

```elixir
{:ok, conversation} = Shadowfax.Chat.find_or_create_conversation(alice.id, bob.id)

# This returns an existing conversation or creates a new one
```

### Step 3: Send a direct message

```elixir
{:ok, dm} = Shadowfax.Chat.create_direct_message(%{
  content: "Hey Bob, can we discuss the project?",
  user_id: alice.id,
  direct_conversation_id: conversation.id
})
```

---

## Viewing Messages

### View messages in a channel

```elixir
# Get the general channel
general = Shadowfax.Chat.get_channel_by_name("general")

# List recent messages (default: 50 messages)
messages = Shadowfax.Chat.list_channel_messages(general.id)

# View just the first message
hd(messages).content
```

### View messages with a limit

```elixir
# Get only the last 10 messages
messages = Shadowfax.Chat.list_channel_messages(general.id, limit: 10)
```

### View direct messages

```elixir
# Get the conversation
alice = Shadowfax.Accounts.get_user_by_email("alice@example.com")
bob = Shadowfax.Accounts.get_user_by_email("bob@example.com")
{:ok, conversation} = Shadowfax.Chat.find_or_create_conversation(alice.id, bob.id)

# List messages
messages = Shadowfax.Chat.list_direct_messages(conversation.id)
```

---

## Advanced Operations

### Update a message

```elixir
# Send a message
{:ok, message} = Shadowfax.Chat.create_channel_message(%{
  content: "Original message",
  user_id: alice.id,
  channel_id: general.id
})

# Edit the message
{:ok, updated} = Shadowfax.Chat.update_message(message, %{
  content: "Updated message"
})

# Check if edited
updated.edited_at
# => ~N[2025-10-02 17:30:00] (timestamp when edited)
```

### Delete a message (soft delete)

```elixir
{:ok, deleted} = Shadowfax.Chat.delete_message(message)

deleted.is_deleted
# => true
```

### Create a threaded reply

```elixir
# Get a parent message (first message in general channel)
parent = hd(Shadowfax.Chat.list_channel_messages(general.id))

# Reply to it
{:ok, reply} = Shadowfax.Chat.create_channel_message(%{
  content: "This is a reply to your message!",
  user_id: alice.id,
  channel_id: general.id,
  parent_message_id: parent.id
})

# View all replies to a message
thread = Shadowfax.Chat.list_thread_messages(parent.id)
```

### Set user online status

```elixir
alice = Shadowfax.Accounts.get_user_by_email("alice@example.com")

# Set online
{:ok, online_alice} = Shadowfax.Accounts.set_user_online(alice)

# Set offline
{:ok, offline_alice} = Shadowfax.Accounts.set_user_offline(online_alice)

# Set custom status
{:ok, away_alice} = Shadowfax.Accounts.update_user_status(alice, %{
  is_online: true,
  status: "away"
})
```

### Search for messages

```elixir
# Search messages containing "project"
results = Shadowfax.Chat.search_messages("project", channel_id: general.id)

# Search across all channels
results = Shadowfax.Chat.search_messages("project")
```

### Join a channel

```elixir
# Get a user and channel
charlie = Shadowfax.Accounts.get_user_by_email("charlie@example.com")
dev_channel = Shadowfax.Chat.get_channel_by_name("development")

# Add user to channel
{:ok, membership} = Shadowfax.Chat.add_user_to_channel(
  dev_channel.id,
  charlie.id,
  "member"  # role: "member", "admin", or "owner"
)
```

### Leave a channel

```elixir
{:ok, _} = Shadowfax.Chat.remove_user_from_channel(dev_channel.id, charlie.id)
```

### View channel members

```elixir
general = Shadowfax.Chat.get_channel_by_name("general")
members = Shadowfax.Chat.list_channel_members(general.id)

# Count members
length(members)
```

---

## Complete Example Workflow

Here's a complete example of Alice sending a message:

```elixir
# 1. Start IEx
# iex -S mix

# 2. Import aliases for convenience
alias Shadowfax.{Accounts, Chat, Repo}

# 3. Get Alice
alice = Accounts.get_user_by_email("alice@example.com")

# 4. Get the channel
general = Chat.get_channel_by_name("general")

# 5. Send a message
{:ok, message} = Chat.create_channel_message(%{
  content: "Good morning everyone! How's everyone doing today?",
  user_id: alice.id,
  channel_id: general.id
})

# 6. Verify it was sent
IO.puts("Message sent: #{message.content}")

# 7. View all messages in the channel
messages = Chat.list_channel_messages(general.id)
Enum.each(messages, fn msg ->
  IO.puts("#{msg.id}: #{msg.content}")
end)
```

---

## Testing Authentication & Using Authenticated Users

### Console Authentication (IEx)

Since your users were created with hashed passwords, you can test authentication in the console:

```elixir
# Try to authenticate Alice
user = Shadowfax.Accounts.get_user_by_email_and_password(
  "alice@example.com",
  "Password123!"
)

# If successful, user will be the User struct
# If failed, user will be nil
```

### HTTP API Authentication

**All API routes except `/api/auth/register` and `/api/auth/login` require authentication.**

#### 1. Register a New User

```bash
curl -X POST http://localhost:4000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "username": "newuser",
      "email": "newuser@example.com",
      "password": "SecurePassword123!",
      "first_name": "New",
      "last_name": "User"
    }
  }'
```

Response:
```json
{
  "success": true,
  "data": {
    "user": { "id": 5, "username": "newuser", ... },
    "token": "SFMyNTY.g3QAAAACZAAEZGF0YW0AAAAEAQIDBGQABnNpZ25lZG4GALi-YZaDAQ.YourTokenHere"
  }
}
```

#### 2. Login (Get Token)

```bash
curl -X POST http://localhost:4000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "alice@example.com",
    "password": "Password123!"
  }'
```

Response:
```json
{
  "success": true,
  "data": {
    "user": { "id": 1, "username": "alice", ... },
    "token": "SFMyNTY.g3QAAAACZAAEZGF0YW0AAAAEAQIDBGQABnNpZ25lZG4GALi-YZaDAQ.YourTokenHere"
  }
}
```

**⚠️ Important: Save this token! You'll need it for all authenticated requests.**

#### 3. Use Token for Authenticated Requests

All protected endpoints require the `Authorization` header with format: `Bearer <token>`

**Example: Send a Channel Message**

```bash
curl -X POST http://localhost:4000/api/channels/1/messages \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer SFMyNTY.g3QAAAACZAAEZGF0YW0AAAAEAQIDBGQABnNpZ25lZG4GALi-YZaDAQ.YourTokenHere" \
  -d '{
    "message": {
      "content": "Hello from the API!"
    }
  }'
```

**Example: Get My User Info**

```bash
curl -X GET http://localhost:4000/api/auth/me \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

**Example: List My Conversations**

```bash
curl -X GET http://localhost:4000/api/conversations \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

**Example: Update My Status**

```bash
curl -X PUT http://localhost:4000/api/users/status \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -d '{
    "status": "away",
    "is_online": true
  }'
```

#### 4. WebSocket Authentication

To connect to WebSocket channels, you need to authenticate:

```javascript
// In your frontend JavaScript
const socket = new Phoenix.Socket("/socket", {
  params: { token: "YOUR_TOKEN_HERE" }
})

socket.connect()

// Join a channel
const channel = socket.channel("chat:1", {})
channel.join()
  .receive("ok", resp => { console.log("Joined successfully", resp) })
  .receive("error", resp => { console.log("Unable to join", resp) })

// Send a message
channel.push("new_message", { content: "Hello!" })
```

#### 5. Token Expiration

- Tokens are valid for **2 weeks (1,209,600 seconds)**
- After expiration, you'll receive a `401 Unauthorized` response
- Simply login again to get a new token

### Security Notes

✅ **User ID is always enforced from the token** - you cannot spoof messages as another user
✅ **All routes except register/login require authentication**
✅ **WebSocket connections verify token on connect**
✅ **Message `user_id` is set server-side from authenticated user**

### Quick Testing Script

Save this as `test_api.sh`:

```bash
#!/bin/bash

# Login and get token
RESPONSE=$(curl -s -X POST http://localhost:4000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "alice@example.com", "password": "Password123!"}')

TOKEN=$(echo $RESPONSE | jq -r '.data.token')

echo "Token: $TOKEN"
echo ""

# Send a message
echo "Sending message..."
curl -X POST http://localhost:4000/api/channels/1/messages \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"message": {"content": "Hello from authenticated API!"}}'

echo ""
echo "Done!"
```

Make it executable and run:
```bash
chmod +x test_api.sh
./test_api.sh
```

---

## Useful Shortcuts

Add these to your `.iex.exs` file in the project root to make working in IEx easier:

```elixir
# .iex.exs
alias Shadowfax.{Accounts, Chat, Repo}
alias Shadowfax.Accounts.User
alias Shadowfax.Chat.{Channel, Message, DirectConversation}

# Helper to get user by username
defmodule H do
  def user(username), do: Shadowfax.Accounts.get_user_by_username(username)
  def channel(name), do: Shadowfax.Chat.get_channel_by_name(name)

  def send_msg(username, channel_name, content) do
    user = user(username)
    channel = channel(channel_name)

    Shadowfax.Chat.create_channel_message(%{
      content: content,
      user_id: user.id,
      channel_id: channel.id
    })
  end
end

IO.puts """
Shadowfax Chat Console Ready!

Quick helpers:
  H.user("alice")                           # Get user by username
  H.channel("general")                      # Get channel by name
  H.send_msg("alice", "general", "Hello!")  # Send message quickly
"""
```

Now you can use shortcuts:

```elixir
# Get Alice quickly
alice = H.user("alice")

# Send a message quickly
H.send_msg("alice", "general", "This is so much easier!")
```

---

## Database Queries

You can also query the database directly:

```elixir
# Count all users
Repo.aggregate(User, :count)

# Count all messages
Repo.aggregate(Message, :count)

# Get messages from today
today = Date.utc_today()
start_of_day = NaiveDateTime.new!(today, ~T[00:00:00])

Repo.all(from m in Message, where: m.inserted_at >= ^start_of_day)
```

---

## Testing Presence (Online/Offline Status)

Shadowfax uses **Phoenix.Presence** to track who's online in real-time. Unlike database-based presence, this tracks users who are actively connected to channels via WebSocket.

### How Presence Works

- **Automatic Tracking**: Users are tracked as "online" when they join a channel
- **Real-time Updates**: Clients receive `presence_state` and `presence_diff` events
- **No Database**: Presence is tracked in-memory, not in the database
- **Per-Channel**: Users are tracked separately for each channel they join

### Testing Presence in IEx

#### 1. Start the Application

```bash
iex -S mix phx.server
```

#### 2. Check Presence for a Channel

```elixir
# Check who's online in the general channel (ID: 1)
ShadowfaxWeb.Presence.list("chat:1")
# => %{} (empty if no one is connected)
```

#### 3. Simulate User Connection (Advanced)

```elixir
# Get a user
alice = Shadowfax.Accounts.get_user_by_email("alice@example.com")

# Manually track presence (this simulates a connection)
{:ok, _ref} = ShadowfaxWeb.Presence.track(
  self(),
  "chat:1",
  alice.id,
  %{
    user_id: alice.id,
    username: alice.username,
    first_name: alice.first_name,
    last_name: alice.last_name,
    avatar_url: alice.avatar_url,
    status: alice.status,
    online_at: DateTime.utc_now() |> DateTime.to_iso8601()
  }
)

# Now check presence again
ShadowfaxWeb.Presence.list("chat:1")
# => %{
#   "1" => %{
#     metas: [
#       %{
#         user_id: 1,
#         username: "alice",
#         first_name: "Alice",
#         ...
#       }
#     ]
#   }
# }
```

### Testing Presence via WebSocket (Frontend)

The best way to test presence is through a WebSocket client. Here's a JavaScript example:

```javascript
// Connect to the socket with authentication
const socket = new Phoenix.Socket("/socket", {
  params: { token: "YOUR_AUTH_TOKEN_HERE" }
})

socket.connect()

// Create a presence object to track state
const presence = new Phoenix.Presence(socket.channel("chat:1"))

// Join the channel
const channel = socket.channel("chat:1", {})

// Listen for presence events
presence.onSync(() => {
  console.log("Online users:", presence.list())
})

// Join the channel
channel.join()
  .receive("ok", resp => {
    console.log("Joined successfully", resp)
  })
  .receive("error", resp => {
    console.log("Unable to join", resp)
  })

// You'll receive presence_state when you join
channel.on("presence_state", state => {
  console.log("Initial presence state:", state)
  presence.syncState(state)
})

// You'll receive presence_diff when users join/leave
channel.on("presence_diff", diff => {
  console.log("Presence changed:", diff)
  presence.syncDiff(diff)
})
```

### Testing Presence with curl + websocat

If you don't have a frontend, you can use `websocat` (WebSocket client):

#### 1. Install websocat

```bash
# macOS
brew install websocat

# Linux
cargo install websocat
```

#### 2. Get Authentication Token

```bash
TOKEN=$(curl -s -X POST http://localhost:4000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "alice@example.com", "password": "Password123!"}' \
  | jq -r '.data.token')

echo "Token: $TOKEN"
```

#### 3. Connect to WebSocket

```bash
websocat "ws://localhost:4000/socket/websocket?token=$TOKEN&vsn=2.0.0"
```

#### 4. Join a Channel

Once connected, send this JSON message:

```json
["1","1","chat:1","phx_join",{}]
```

You should receive a `presence_state` message showing who's online.

### Running Presence Tests

Run the test suite:

```bash
# Run all tests
mix test

# Run only presence tests
mix test test/shadowfax_web/channels/presence_test.exs

# Run with verbose output
mix test test/shadowfax_web/channels/presence_test.exs --trace
```

### Understanding Presence Data Structure

When you call `Presence.list("chat:1")`, you get:

```elixir
%{
  "1" => %{  # User ID as key
    metas: [  # Array of presence metadata (usually 1 entry per user)
      %{
        user_id: 1,
        username: "alice",
        first_name: "Alice",
        last_name: "Wonder",
        avatar_url: "https://...",
        status: "available",  # available, away, busy, dnd
        online_at: "2025-10-03T15:39:11Z",
        phx_ref: "F-Q0j8K9H5k="  # Phoenix internal reference
      }
    ]
  },
  "2" => %{
    metas: [...]
  }
}
```

### Checking Online Users Programmatically

```elixir
# Get all online users in a channel
defmodule PresenceHelper do
  def online_users(channel_topic) do
    ShadowfaxWeb.Presence.list(channel_topic)
    |> Enum.map(fn {_user_id, %{metas: [meta | _]}} ->
      %{
        id: meta.user_id,
        username: meta.username,
        status: meta.status
      }
    end)
  end

  def count_online(channel_topic) do
    ShadowfaxWeb.Presence.list(channel_topic)
    |> map_size()
  end

  def user_online?(channel_topic, user_id) do
    ShadowfaxWeb.Presence.list(channel_topic)
    |> Map.has_key?("#{user_id}")
  end
end

# Usage
PresenceHelper.online_users("chat:1")
# => [%{id: 1, username: "alice", status: "available"}]

PresenceHelper.count_online("chat:1")
# => 1

PresenceHelper.user_online?("chat:1", 1)
# => true
```

### Important Notes

- **Presence is per-channel**: A user can be online in one channel but not in another
- **No database queries**: Presence is tracked in-memory for performance
- **Automatic cleanup**: When a user disconnects, they're automatically removed
- **Status field**: Users can set their status to "available", "away", "busy", or "dnd"
- **WebSocket required**: Presence only works for users connected via WebSocket, not REST API

### Debugging Presence Issues

If presence isn't working:

1. **Check if Presence is running**:
   ```elixir
   Process.whereis(ShadowfaxWeb.Presence)
   # Should return a PID like #PID<0.456.0>
   ```

2. **Check if user is authenticated**:
   ```elixir
   # In your channel test
   socket.assigns.current_user_id
   # Should return the user ID
   ```

3. **Check channel subscription**:
   ```elixir
   Phoenix.PubSub.subscribers(Shadowfax.PubSub, "chat:1")
   # Should show connected PIDs
   ```

4. **Enable debug logging** in `config/dev.exs`:
   ```elixir
   config :logger, level: :debug
   ```
