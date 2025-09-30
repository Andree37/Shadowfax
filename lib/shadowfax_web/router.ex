defmodule ShadowfaxWeb.Router do
  use ShadowfaxWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", ShadowfaxWeb do
    pipe_through :api

    post "/auth/login", AuthController, :login
    post "/auth/register", AuthController, :register
    delete "/auth/logout", AuthController, :logout

    # Chat API routes
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

    # Direct messages
    get "/conversations", ConversationController, :index
    post "/conversations", ConversationController, :create
    get "/conversations/:id", ConversationController, :show
    get "/conversations/:id/messages", ConversationController, :messages
    post "/conversations/:id/messages", MessageController, :create_direct_message

    # Messages
    get "/messages/:id", MessageController, :show
    put "/messages/:id", MessageController, :update
    delete "/messages/:id", MessageController, :delete
    get "/messages/search", MessageController, :search

    # Users
    get "/users", UserController, :index
    get "/users/:id", UserController, :show
    put "/users/:id", UserController, :update
    get "/users/search", UserController, :search
  end

  # Enable Swoosh mailbox preview in development
  if Application.compile_env(:shadowfax, :dev_routes) do
    scope "/dev" do
      pipe_through [:api]

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
