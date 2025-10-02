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

# Get all online users
import Ecto.Query
Repo.all(from u in User, where: u.is_online == true)

# Get messages from today
today = Date.utc_today()
start_of_day = NaiveDateTime.new!(today, ~T[00:00:00])

Repo.all(from m in Message, where: m.inserted_at >= ^start_of_day)
```
