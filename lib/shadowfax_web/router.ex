defmodule ShadowfaxWeb.Router do
  use ShadowfaxWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug ShadowfaxWeb.Plugs.RateLimitAPI
  end

  pipeline :authenticated do
    plug ShadowfaxWeb.Plugs.Authenticate
  end

  pipeline :rate_limit_auth do
    plug ShadowfaxWeb.Plugs.RateLimitAuth
  end

  pipeline :rate_limit_messages do
    plug ShadowfaxWeb.Plugs.RateLimitMessages
  end

  scope "/api", ShadowfaxWeb do
    pipe_through [:api, :rate_limit_auth]

    # Public auth routes (no authentication required)
    post "/auth/register", AuthController, :register
    post "/auth/login", AuthController, :login
    post "/auth/refresh", AuthController, :refresh
  end

  scope "/api", ShadowfaxWeb do
    pipe_through [:api, :authenticated]

    # Protected auth routes
    delete "/auth/logout", AuthController, :logout
    get "/auth/me", AuthController, :me
    get "/auth/verify", AuthController, :verify_token_endpoint
    get "/auth/sessions", AuthController, :sessions
    delete "/auth/sessions/:id", AuthController, :revoke_session

    # Channel routes
    get "/channels", ChannelController, :index
    post "/channels", ChannelController, :create
    get "/channels/:id", ChannelController, :show
    put "/channels/:id", ChannelController, :update
    delete "/channels/:id", ChannelController, :delete
    post "/channels/:id/join", ChannelController, :join
    delete "/channels/:id/leave", ChannelController, :leave
    get "/channels/:id/members", ChannelController, :members
    get "/channels/:id/messages", ChannelController, :messages
  end

  scope "/api", ShadowfaxWeb do
    pipe_through [:api, :authenticated, :rate_limit_messages]

    # Message creation endpoints (rate limited for spam prevention)
    post "/channels/:id/messages", MessageController, :create_channel_message
    post "/conversations/:id/messages", MessageController, :create_direct_message
  end

  scope "/api", ShadowfaxWeb do
    pipe_through [:api, :authenticated]

    # Direct conversation routes
    get "/conversations", ConversationController, :index
    post "/conversations", ConversationController, :create
    get "/conversations/:id", ConversationController, :show
    get "/conversations/:id/messages", ConversationController, :messages
    post "/conversations/:id/archive", ConversationController, :archive
    post "/conversations/:id/unarchive", ConversationController, :unarchive

    # Message routes
    get "/messages/search", MessageController, :search
    get "/messages/:id", MessageController, :show
    get "/messages/:id/thread", MessageController, :thread
    put "/messages/:id", MessageController, :update
    delete "/messages/:id", MessageController, :delete

    # User routes
    get "/users/search", UserController, :search
    get "/users/stats", UserController, :stats
    get "/users", UserController, :index
    get "/users/:id", UserController, :show
    put "/users/:id", UserController, :update
    put "/users/status", UserController, :update_status
  end

  # Enable Swoosh mailbox preview in development
  if Application.compile_env(:shadowfax, :dev_routes) do
    scope "/dev" do
      pipe_through [:api]

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
