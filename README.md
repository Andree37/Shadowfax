# Shadowfax

Elixir chat server.

# API Routes (lib/shadowfax_web/router.ex)
```
  Public Endpoints (no auth required)

  POST /api/auth/register    # Create account
  POST /api/auth/login       # Login (returns JWT token)

  Authenticated Endpoints (requires Bearer token)

  Auth

  DELETE /api/auth/logout
  GET    /api/auth/me        # Current user info
  GET    /api/auth/verify    # Verify token

  Channels

  GET    /api/channels                # List public + user's channels
  POST   /api/channels                # Create channel
  GET    /api/channels/:id            # Channel details
  PUT    /api/channels/:id            # Update channel
  DELETE /api/channels/:id            # Delete channel
  POST   /api/channels/:id/join       # Join channel
  DELETE /api/channels/:id/leave      # Leave channel
  GET    /api/channels/:id/members    # List members
  GET    /api/channels/:id/messages   # Message history
  POST   /api/channels/:id/messages   # Send message

  Direct Conversations

  GET    /api/conversations              # List user's DMs
  POST   /api/conversations              # Start new DM
  GET    /api/conversations/:id          # Conversation details
  GET    /api/conversations/:id/messages # Message history
  POST   /api/conversations/:id/messages # Send DM
  POST   /api/conversations/:id/archive  # Archive chat

  Messages

  GET    /api/messages/search       # Search messages
  GET    /api/messages/:id          # Get message
  GET    /api/messages/:id/thread   # Get thread replies
  PUT    /api/messages/:id          # Edit message
  DELETE /api/messages/:id          # Delete message

  Users

  GET    /api/users/search    # Search users
  GET    /api/users/stats     # User statistics
  GET    /api/users           # List users
  GET    /api/users/:id       # User profile
  PUT    /api/users/:id       # Update profile
  PUT    /api/users/status    # Update online status
```

# Things to improve
- Authorization checks** - Verify users can only access their own conversations/channels
- JWT secret management** - Ensure proper secret key rotation and storage
- CORS configuration** - Define allowed origins explicitly

- WebSocket/Phoenix Channels** - Currently REST-only; add real-time messaging via Phoenix.Channel
- Presence tracking** - Show who's online using Phoenix.Presence

- Pagination** - Message history endpoints need cursor-based pagination
- Caching** - Cache frequently accessed channels/user data

- Logging** - Add structured logging for security events
- Monitoring** - Expand telemetry for message throughput, auth failures
- Health checks** - Add `/health` endpoint for deployment monitoring

- File uploads** - Support image/file sharing in messages
- Read receipts** - Track message read status
- Notifications** - Email/push notifications for offline users
- Message reactions** - Emojis/reactions on messages
