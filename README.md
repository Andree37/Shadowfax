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
1. Password hashing (user.ex:115) - Replace Base64 with Bcrypt/Argon2
2. Rate limiting - Add rate limits to prevent spam
3. Input sanitization - Message content should be sanitized for XSS
