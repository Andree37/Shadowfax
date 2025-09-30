# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Shadowfax.Repo.insert!(%Shadowfax.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

import Ecto.Query
alias Shadowfax.Repo
alias Shadowfax.Accounts
alias Shadowfax.Chat
alias Shadowfax.Accounts.User
alias Shadowfax.Chat.{Channel, ChannelMembership, DirectConversation, Message}

# Clear existing data in development
if Mix.env() == :dev do
  Repo.delete_all(Message)
  Repo.delete_all(ChannelMembership)
  Repo.delete_all(DirectConversation)
  Repo.delete_all(Channel)
  Repo.delete_all(User)
end

# Create sample users
users = [
  %{
    username: "alice",
    email: "alice@example.com",
    password: "Password123!",
    first_name: "Alice",
    last_name: "Johnson",
    status: "online",
    is_online: true
  },
  %{
    username: "bob",
    email: "bob@example.com",
    password: "Password123!",
    first_name: "Bob",
    last_name: "Smith",
    status: "away",
    is_online: true
  },
  %{
    username: "charlie",
    email: "charlie@example.com",
    password: "Password123!",
    first_name: "Charlie",
    last_name: "Brown",
    status: "busy",
    is_online: false
  },
  %{
    username: "diana",
    email: "diana@example.com",
    password: "Password123!",
    first_name: "Diana",
    last_name: "Prince",
    status: "online",
    is_online: true
  },
  %{
    username: "eve",
    email: "eve@example.com",
    password: "Password123!",
    first_name: "Eve",
    last_name: "Adams",
    status: "offline",
    is_online: false
  }
]

IO.puts("Creating users...")

created_users =
  Enum.map(users, fn user_attrs ->
    {:ok, user} = Accounts.create_user(user_attrs)
    IO.puts("  Created user: #{user.username}")
    user
  end)

[alice, bob, charlie, diana, eve] = created_users

# Create sample channels
channels = [
  %{
    name: "general",
    description: "General discussion for everyone",
    topic: "Welcome to the general channel!",
    is_private: false,
    created_by_id: alice.id
  },
  %{
    name: "random",
    description: "Random conversations and fun stuff",
    topic: "Anything goes here!",
    is_private: false,
    created_by_id: bob.id
  },
  %{
    name: "development",
    description: "Development discussions and updates",
    topic: "Code, bugs, and features",
    is_private: false,
    created_by_id: alice.id
  },
  %{
    name: "private-team",
    description: "Private team discussions",
    topic: "Team members only",
    is_private: true,
    max_members: 10,
    created_by_id: diana.id
  },
  %{
    name: "announcements",
    description: "Important announcements",
    topic: "Company-wide announcements",
    is_private: false,
    created_by_id: alice.id
  }
]

IO.puts("Creating channels...")

created_channels =
  Enum.map(channels, fn channel_attrs ->
    {:ok, channel} = Chat.create_channel(channel_attrs)
    IO.puts("  Created channel: ##{channel.name}")
    channel
  end)

[general, random, development, private_team, announcements] = created_channels

# Add users to channels
IO.puts("Adding users to channels...")

# Everyone joins general
Enum.each(created_users, fn user ->
  # Alice is already added as creator/owner
  unless user.id == alice.id do
    {:ok, _} = Chat.add_user_to_channel(general.id, user.id, "member")
  end
end)

# Add some users to random
[bob, charlie, diana]
|> Enum.each(fn user ->
  # Bob is already added as creator/owner
  unless user.id == bob.id do
    {:ok, _} = Chat.add_user_to_channel(random.id, user.id, "member")
  end
end)

# Add developers to development channel
[alice, bob, eve]
|> Enum.each(fn user ->
  # Alice is already added as creator/owner
  unless user.id == alice.id do
    {:ok, _} = Chat.add_user_to_channel(development.id, user.id, "member")
  end
end)

# Add team members to private team
[alice, bob, diana]
|> Enum.each(fn user ->
  # Diana is already added as creator/owner
  unless user.id == diana.id do
    {:ok, _} = Chat.add_user_to_channel(private_team.id, user.id, "admin")
  end
end)

# Add admin to announcements
{:ok, _} = Chat.add_user_to_channel(announcements.id, diana.id, "admin")

# Create some sample messages in channels
IO.puts("Creating sample messages...")

# Messages in general channel
sample_messages = [
  %{
    content: "Welcome everyone to our new chat platform! 🎉",
    user_id: alice.id,
    channel_id: general.id,
    message_type: "text"
  },
  %{
    content: "Thanks Alice! This looks great. How do I join other channels?",
    user_id: bob.id,
    channel_id: general.id,
    message_type: "text"
  },
  %{
    content: "You can browse public channels or get an invite code for private ones.",
    user_id: alice.id,
    channel_id: general.id,
    message_type: "text"
  },
  %{
    content: "Are we going to migrate all our old conversations here?",
    user_id: charlie.id,
    channel_id: general.id,
    message_type: "text"
  },
  %{
    content: "Eventually, yes. We'll do it gradually to avoid disruption.",
    user_id: diana.id,
    channel_id: general.id,
    message_type: "text"
  }
]

Enum.each(sample_messages, fn message_attrs ->
  {:ok, _} = Chat.create_channel_message(message_attrs)
end)

# Messages in development channel
dev_messages = [
  %{
    content: "I just pushed the authentication fix to staging. Can someone test it?",
    user_id: alice.id,
    channel_id: development.id,
    message_type: "text"
  },
  %{
    content: "On it! I'll check the login flow and OAuth integration.",
    user_id: bob.id,
    channel_id: development.id,
    message_type: "text"
  },
  %{
    content: "Great! Also, don't forget to test password reset functionality.",
    user_id: alice.id,
    channel_id: development.id,
    message_type: "text"
  },
  %{
    content: "Should we create a test checklist for this feature?",
    user_id: eve.id,
    channel_id: development.id,
    message_type: "text"
  }
]

Enum.each(dev_messages, fn message_attrs ->
  {:ok, _} = Chat.create_channel_message(message_attrs)
end)

# Messages in random channel
random_messages = [
  %{
    content: "Anyone know a good coffee shop near the office?",
    user_id: bob.id,
    channel_id: random.id,
    message_type: "text"
  },
  %{
    content: "Blue Bottle Coffee is excellent! About 2 blocks away.",
    user_id: diana.id,
    channel_id: random.id,
    message_type: "text"
  },
  %{
    content: "Thanks! I'll check it out during lunch break. ☕",
    user_id: bob.id,
    channel_id: random.id,
    message_type: "text"
  },
  %{
    content: "Their cold brew is amazing in the summer!",
    user_id: charlie.id,
    channel_id: random.id,
    message_type: "text"
  }
]

Enum.each(random_messages, fn message_attrs ->
  {:ok, _} = Chat.create_channel_message(message_attrs)
end)

# Create some direct conversations
IO.puts("Creating direct conversations...")

# Alice and Bob conversation
{:ok, alice_bob_conv} = Chat.find_or_create_conversation(alice.id, bob.id)

dm_messages_1 = [
  %{
    content: "Hey Bob, do you have a few minutes to discuss the new feature?",
    user_id: alice.id,
    direct_conversation_id: alice_bob_conv.id,
    message_type: "text"
  },
  %{
    content: "Sure! Are you thinking about the real-time notifications?",
    user_id: bob.id,
    direct_conversation_id: alice_bob_conv.id,
    message_type: "text"
  },
  %{
    content: "Exactly. I think we should prioritize push notifications first.",
    user_id: alice.id,
    direct_conversation_id: alice_bob_conv.id,
    message_type: "text"
  },
  %{
    content: "Makes sense. I can start working on the backend implementation.",
    user_id: bob.id,
    direct_conversation_id: alice_bob_conv.id,
    message_type: "text"
  }
]

Enum.each(dm_messages_1, fn message_attrs ->
  {:ok, _} = Chat.create_direct_message(message_attrs)
end)

# Diana and Charlie conversation
{:ok, diana_charlie_conv} = Chat.find_or_create_conversation(diana.id, charlie.id)

dm_messages_2 = [
  %{
    content: "Hi Charlie! How's the UI mockup coming along?",
    user_id: diana.id,
    direct_conversation_id: diana_charlie_conv.id,
    message_type: "text"
  },
  %{
    content: "Good progress! I should have the first draft ready by tomorrow.",
    user_id: charlie.id,
    direct_conversation_id: diana_charlie_conv.id,
    message_type: "text"
  },
  %{
    content: "Perfect! Can you focus on the mobile layout first?",
    user_id: diana.id,
    direct_conversation_id: diana_charlie_conv.id,
    message_type: "text"
  }
]

Enum.each(dm_messages_2, fn message_attrs ->
  {:ok, _} = Chat.create_direct_message(message_attrs)
end)

# Create some system messages
system_messages = [
  %{
    content: "Diana created this channel",
    channel_id: private_team.id,
    message_type: "system",
    metadata: %{action: "channel_created", user_id: diana.id}
  },
  %{
    content: "Alice joined the channel",
    channel_id: private_team.id,
    message_type: "system",
    metadata: %{action: "user_joined", user_id: alice.id}
  },
  %{
    content: "Bob joined the channel",
    channel_id: private_team.id,
    message_type: "system",
    metadata: %{action: "user_joined", user_id: bob.id}
  }
]

Enum.each(system_messages, fn message_attrs ->
  {:ok, _} = Chat.create_system_message(message_attrs)
end)

# Create some threaded messages (replies)
IO.puts("Creating threaded messages...")

# Get a message to reply to
parent_message = Repo.one(from m in Message, where: m.channel_id == ^development.id, limit: 1)

if parent_message do
  thread_replies = [
    %{
      content: "I can help with the testing too if needed.",
      user_id: alice.id,
      channel_id: development.id,
      parent_message_id: parent_message.id,
      message_type: "text"
    },
    %{
      content: "That would be great! The more eyes on this, the better.",
      user_id: bob.id,
      channel_id: development.id,
      parent_message_id: parent_message.id,
      message_type: "text"
    }
  ]

  Enum.each(thread_replies, fn message_attrs ->
    {:ok, _} = Chat.create_channel_message(message_attrs)
  end)
end

IO.puts("✅ Seed data created successfully!")

IO.puts("""

Sample accounts created:
- alice@example.com / Password123!
- bob@example.com / Password123!
- charlie@example.com / Password123!
- diana@example.com / Password123!
- eve@example.com / Password123!

Channels created:
- #general (public) - All users
- #random (public) - Bob, Charlie, Diana
- #development (public) - Alice, Bob, Eve
- #private-team (private) - Alice, Bob, Diana
- #announcements (public) - Alice, Diana

Direct conversations:
- Alice ↔ Bob
- Diana ↔ Charlie

You can now start the server with: mix phx.server
""")
