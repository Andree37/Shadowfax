defmodule ShadowfaxWeb.MessageController do
  use ShadowfaxWeb, :controller

  alias Shadowfax.Chat
  alias Shadowfax.Accounts.User
  alias Shadowfax.Chat.{Message, Channel}
  alias ShadowfaxWeb.Errors

  @doc """
  Create a channel message
  """
  def create_channel_message(conn, %{"id" => channel_id, "message" => message_params}) do
    with {:ok, user} <- get_current_user(conn),
         channel <- Chat.get_channel!(channel_id),
         true <- can_access_channel?(channel, user.id),
         message_attrs <-
           Map.merge(message_params, %{"user_id" => user.id, "channel_id" => channel_id}),
         {:ok, message} <- Chat.create_channel_message(message_attrs) do
      message = Shadowfax.Repo.preload(message, [:user, :parent_message])

      conn
      |> put_status(:created)
      |> json(%{
        success: true,
        data: %{
          message: serialize_message(message)
        }
      })
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> json(%{
          success: false,
          error: Errors.must_be_member()
        })

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          success: false,
          errors: serialize_errors(changeset)
        })
    end
  rescue
    Ecto.NoResultsError ->
      conn
      |> put_status(:not_found)
      |> json(%{
        success: false,
        error: Errors.channel_not_found()
      })
  end

  def create_channel_message(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{
      success: false,
      error: Errors.invalid_request("message")
    })
  end

  @doc """
  Create a direct message
  """
  def create_direct_message(conn, %{"id" => conversation_id, "message" => message_params}) do
    with {:ok, user} <- get_current_user(conn),
         conversation <- Chat.get_direct_conversation!(conversation_id),
         true <- can_access_conversation?(conversation, user.id),
         message_attrs <-
           Map.merge(message_params, %{
             "user_id" => user.id,
             "direct_conversation_id" => conversation_id
           }),
         {:ok, message} <- Chat.create_direct_message(message_attrs) do
      message = Shadowfax.Repo.preload(message, [:user, :parent_message])

      conn
      |> put_status(:created)
      |> json(%{
        success: true,
        data: %{
          message: serialize_message(message)
        }
      })
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> json(%{
          success: false,
          error: Errors.access_denied()
        })

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          success: false,
          errors: serialize_errors(changeset)
        })
    end
  rescue
    Ecto.NoResultsError ->
      conn
      |> put_status(:not_found)
      |> json(%{
        success: false,
        error: Errors.conversation_not_found()
      })
  end

  def create_direct_message(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{
      success: false,
      error: Errors.invalid_request("message")
    })
  end

  @doc """
  Show a specific message
  """
  def show(conn, %{"id" => id}) do
    with {:ok, user} <- get_current_user(conn),
         message <- Chat.get_message!(id),
         message <-
           Shadowfax.Repo.preload(message, [
             :user,
             :parent_message,
             :channel,
             :direct_conversation
           ]),
         true <- can_access_message?(message, user.id) do
      conn
      |> json(%{
        success: true,
        data: %{
          message: serialize_message(message)
        }
      })
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> json(%{
          success: false,
          error: Errors.access_denied()
        })
    end
  rescue
    Ecto.NoResultsError ->
      conn
      |> put_status(:not_found)
      |> json(%{
        success: false,
        error: Errors.message_not_found()
      })
  end

  @doc """
  Update a message
  """
  def update(conn, %{"id" => id, "message" => message_params}) do
    with {:ok, user} <- get_current_user(conn),
         message <- Chat.get_message!(id),
         true <- Message.can_edit?(message, user.id),
         {:ok, updated_message} <- Chat.update_message(message, message_params) do
      updated_message = Shadowfax.Repo.preload(updated_message, [:user, :parent_message])

      conn
      |> json(%{
        success: true,
        data: %{
          message: serialize_message(updated_message)
        }
      })
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> json(%{
          success: false,
          error: Errors.own_message_edit_only()
        })

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          success: false,
          errors: serialize_errors(changeset)
        })
    end
  rescue
    Ecto.NoResultsError ->
      conn
      |> put_status(:not_found)
      |> json(%{
        success: false,
        error: Errors.message_not_found()
      })
  end

  def update(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{
      success: false,
      error: Errors.invalid_request("message")
    })
  end

  @doc """
  Delete a message
  """
  def delete(conn, %{"id" => id}) do
    with {:ok, user} <- get_current_user(conn),
         message <- Chat.get_message!(id),
         message <- Shadowfax.Repo.preload(message, [:channel]),
         user_role <- get_user_role(message, user.id),
         true <- Message.can_delete?(message, user.id, user_role),
         {:ok, _deleted_message} <- Chat.delete_message(message) do
      conn
      |> json(%{
        success: true,
        message: "Message deleted successfully"
      })
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> json(%{
          success: false,
          error: Errors.delete_permission_denied()
        })

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          success: false,
          errors: serialize_errors(changeset)
        })
    end
  rescue
    Ecto.NoResultsError ->
      conn
      |> put_status(:not_found)
      |> json(%{
        success: false,
        error: Errors.message_not_found()
      })
  end

  @doc """
  Search messages with cursor-based pagination

  Query parameters:
  - q: Search query (required)
  - limit: Maximum number of messages (default: 25, max: 100)
  - before: Fetch messages before this cursor (message ID)
  - after: Fetch messages after this cursor (message ID)
  - channel_id: Filter by channel ID
  - conversation_id: Filter by conversation ID
  """
  def search(conn, %{"q" => query} = params) do
    {:ok, user} = get_current_user(conn)
    opts = build_search_opts(params, user.id)
    result = Chat.search_messages(query, opts)

    # Filter messages based on access
    accessible_messages =
      Enum.filter(result.messages, fn message ->
        can_access_message?(message, user.id)
      end)

    conn
    |> json(%{
      success: true,
      data: %{
        messages: Enum.map(accessible_messages, &serialize_message/1),
        query: query,
        pagination: %{
          has_more: result.has_more,
          next_cursor: result.next_cursor,
          prev_cursor: result.prev_cursor
        }
      }
    })
  end

  def search(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{
      success: false,
      error: Errors.search_query_required()
    })
  end

  @doc """
  Get thread messages (replies to a parent message) with cursor-based pagination

  Query parameters:
  - limit: Maximum number of messages (default: 50, max: 100)
  - before: Fetch messages before this cursor (message ID)
  - after: Fetch messages after this cursor (message ID)
  """
  def thread(conn, %{"id" => parent_message_id} = params) do
    with {:ok, user} <- get_current_user(conn),
         parent_message <- Chat.get_message!(parent_message_id),
         parent_message <-
           Shadowfax.Repo.preload(parent_message, [:user, :channel, :direct_conversation]),
         true <- can_access_message?(parent_message, user.id) do
      opts = build_thread_opts(params)
      result = Chat.list_thread_messages(parent_message.id, opts)

      conn
      |> json(%{
        success: true,
        data: %{
          parent_message: serialize_message(parent_message),
          replies: Enum.map(result.messages, &serialize_message/1),
          pagination: %{
            has_more: result.has_more,
            next_cursor: result.next_cursor,
            prev_cursor: result.prev_cursor
          }
        }
      })
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> json(%{
          success: false,
          error: Errors.access_denied()
        })
    end
  rescue
    Ecto.NoResultsError ->
      conn
      |> put_status(:not_found)
      |> json(%{
        success: false,
        error: Errors.message_not_found()
      })
  end

  # Private functions

  defp get_current_user(conn) do
    # The authentication plug ensures current_user is always present
    {:ok, conn.assigns.current_user}
  end

  defp can_access_channel?(%Channel{is_private: false}, _user_id), do: true

  defp can_access_channel?(%Channel{} = channel, user_id),
    do: Channel.is_member?(channel, user_id)

  defp can_access_conversation?(conversation, user_id) do
    conversation.user1_id == user_id || conversation.user2_id == user_id
  end

  defp can_access_message?(%Message{channel_id: channel_id} = message, user_id)
       when not is_nil(channel_id) do
    channel = message.channel || Chat.get_channel!(channel_id)
    can_access_channel?(channel, user_id)
  rescue
    Ecto.NoResultsError -> false
  end

  defp can_access_message?(
         %Message{direct_conversation_id: conversation_id} = message,
         user_id
       )
       when not is_nil(conversation_id) do
    conversation =
      message.direct_conversation || Chat.get_direct_conversation!(conversation_id)

    can_access_conversation?(conversation, user_id)
  rescue
    Ecto.NoResultsError -> false
  end

  defp can_access_message?(_message, _user_id), do: false

  defp get_user_role(%Message{channel_id: channel_id}, user_id)
       when not is_nil(channel_id) do
    case Chat.get_channel_membership(channel_id, user_id) do
      nil -> "member"
      membership -> membership.role
    end
  end

  defp get_user_role(_message, _user_id), do: "member"

  defp build_search_opts(params, _user_id) do
    opts = []

    opts =
      if channel_id = params["channel_id"] do
        Keyword.put(opts, :channel_id, String.to_integer(channel_id))
      else
        opts
      end

    opts =
      if conversation_id = params["conversation_id"] do
        Keyword.put(opts, :conversation_id, String.to_integer(conversation_id))
      else
        opts
      end

    opts =
      if limit = params["limit"] do
        Keyword.put(opts, :limit, min(String.to_integer(limit), 100))
      else
        Keyword.put(opts, :limit, 25)
      end

    opts =
      if before = params["before"] do
        Keyword.put(opts, :before, String.to_integer(before))
      else
        opts
      end

    opts =
      if after_cursor = params["after"] do
        Keyword.put(opts, :after, String.to_integer(after_cursor))
      else
        opts
      end

    opts
  rescue
    ArgumentError -> []
  end

  defp build_thread_opts(params) do
    opts = []

    opts =
      if limit = params["limit"] do
        Keyword.put(opts, :limit, min(String.to_integer(limit), 100))
      else
        Keyword.put(opts, :limit, 50)
      end

    opts =
      if before = params["before"] do
        Keyword.put(opts, :before, String.to_integer(before))
      else
        opts
      end

    opts =
      if after_cursor = params["after"] do
        Keyword.put(opts, :after, String.to_integer(after_cursor))
      else
        opts
      end

    opts
  rescue
    ArgumentError -> []
  end

  defp serialize_message(message) do
    %{
      id: message.id,
      content: message.content,
      message_type: message.message_type,
      edited_at: message.edited_at,
      is_deleted: message.is_deleted,
      metadata: message.metadata || %{},
      attachments: message.attachments || [],
      inserted_at: message.inserted_at,
      updated_at: message.updated_at,
      user: serialize_user(message.user),
      parent_message_id: message.parent_message_id,
      channel_id: message.channel_id,
      direct_conversation_id: message.direct_conversation_id
    }
  end

  defp serialize_user(%User{} = user) do
    %{
      id: user.id,
      username: user.username,
      first_name: user.first_name,
      last_name: user.last_name,
      avatar_url: user.avatar_url,
      status: user.status,
      display_name: User.display_name(user)
    }
  end

  defp serialize_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
