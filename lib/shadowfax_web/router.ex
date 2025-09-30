defmodule ShadowfaxWeb.Router do
  use ShadowfaxWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", ShadowfaxWeb do
    pipe_through :api

    # Auth routes
    post "/auth/register", AuthController, :register
    post "/auth/login", AuthController, :login
    delete "/auth/logout", AuthController, :logout
    get "/auth/me", AuthController, :me
    get "/auth/verify", AuthController, :verify_token

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
    post "/channels/:id/messages", MessageController, :create_channel_message

    # Direct conversation routes
    get "/conversations", ConversationController, :index
    post "/conversations", ConversationController, :create
    get "/conversations/:id", ConversationController, :show
    get "/conversations/:id/messages", ConversationController, :messages
    post "/conversations/:id/messages", MessageController, :create_direct_message
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
