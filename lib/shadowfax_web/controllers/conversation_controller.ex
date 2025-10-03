defmodule ShadowfaxWeb.ConversationController do
  use ShadowfaxWeb, :controller

  alias Shadowfax.Chat
  alias Shadowfax.Accounts
  alias Shadowfax.Accounts.User
  alias Shadowfax.Chat.DirectConversation

  @doc """
  List all conversations for the authenticated user
  """
  def index(conn, _params) do
    {:ok, user} = get_current_user(conn)
    conversations = Chat.list_user_conversations(user.id)

    conn
    |> json(%{
      success: true,
      data: %{
        conversations:
          Enum.map(conversations, fn conv -> serialize_conversation(conv, user.id) end)
      }
    })
  end

  @doc """
  Create or get a direct conversation with another user
  """
  def create(conn, %{"user_id" => other_user_id}) do
    with {:ok, user} <- get_current_user(conn),
         true <- user.id != other_user_id,
         {:ok, _other_user} <- get_user(other_user_id),
         {:ok, conversation} <- Chat.find_or_create_conversation(user.id, other_user_id) do
      conversation = Shadowfax.Repo.preload(conversation, [:user1, :user2])

      conn
      |> put_status(:created)
      |> json(%{
        success: true,
        data: %{
          conversation: serialize_conversation(conversation, user.id)
        }
      })
    else
      false ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          success: false,
          error: "Cannot create conversation with yourself"
        })

      {:error, :user_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{
          success: false,
          error: "User not found"
        })

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          success: false,
          errors: serialize_errors(changeset)
        })
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{
      success: false,
      error: "Invalid request format. Expected 'user_id' parameter."
    })
  end

  @doc """
  Show a specific conversation
  """
  def show(conn, %{"id" => id}) do
    with {:ok, user} <- get_current_user(conn),
         conversation <- Chat.get_direct_conversation!(id),
         conversation <- Shadowfax.Repo.preload(conversation, [:user1, :user2]),
         true <- can_access_conversation?(conversation, user.id) do
      conn
      |> json(%{
        success: true,
        data: %{
          conversation: serialize_conversation(conversation, user.id)
        }
      })
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> json(%{
          success: false,
          error: "Access denied"
        })
    end
  rescue
    Ecto.NoResultsError ->
      conn
      |> put_status(:not_found)
      |> json(%{
        success: false,
        error: "Conversation not found"
      })
  end

  @doc """
  Get messages in a conversation
  """
  def messages(conn, %{"id" => id} = params) do
    with {:ok, user} <- get_current_user(conn),
         conversation <- Chat.get_direct_conversation!(id),
         true <- can_access_conversation?(conversation, user.id) do
      limit = min(String.to_integer(params["limit"] || "50"), 100)
      offset = String.to_integer(params["offset"] || "0")

      messages = Chat.list_direct_messages(conversation.id, limit: limit, offset: offset)

      conn
      |> json(%{
        success: true,
        data: %{
          messages: Enum.map(messages, &serialize_message/1),
          conversation: serialize_conversation(conversation, user.id)
        }
      })
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> json(%{
          success: false,
          error: "Access denied"
        })
    end
  rescue
    Ecto.NoResultsError ->
      conn
      |> put_status(:not_found)
      |> json(%{
        success: false,
        error: "Conversation not found"
      })

    ArgumentError ->
      conn
      |> put_status(:bad_request)
      |> json(%{
        success: false,
        error: "Invalid limit or offset parameter"
      })
  end

  @doc """
  Archive a conversation
  """
  def archive(conn, %{"id" => id}) do
    with {:ok, user} <- get_current_user(conn),
         conversation <- Chat.get_direct_conversation!(id),
         true <- can_access_conversation?(conversation, user.id),
         {:ok, archived_conversation} <-
           Chat.archive_conversation_for_user(conversation, user.id, true) do
      conn
      |> json(%{
        success: true,
        data: %{
          conversation: serialize_conversation(archived_conversation, user.id)
        }
      })
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> json(%{
          success: false,
          error: "Access denied"
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
        error: "Conversation not found"
      })
  end

  @doc """
  Unarchive a conversation
  """
  def unarchive(conn, %{"id" => id}) do
    with {:ok, user} <- get_current_user(conn),
         conversation <- Chat.get_direct_conversation!(id),
         true <- can_access_conversation?(conversation, user.id),
         {:ok, unarchived_conversation} <-
           Chat.archive_conversation_for_user(conversation, user.id, false) do
      conn
      |> json(%{
        success: true,
        data: %{
          conversation: serialize_conversation(unarchived_conversation, user.id)
        }
      })
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> json(%{
          success: false,
          error: "Access denied"
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
        error: "Conversation not found"
      })
  end

  # Private functions

  defp get_current_user(conn) do
    # The authentication plug ensures current_user is always present
    {:ok, conn.assigns.current_user}
  end

  defp get_user(user_id) when is_integer(user_id) do
    try do
      {:ok, Accounts.get_user!(user_id)}
    rescue
      Ecto.NoResultsError -> {:error, :user_not_found}
    end
  end

  defp get_user(user_id) when is_binary(user_id) do
    try do
      {:ok, Accounts.get_user!(String.to_integer(user_id))}
    rescue
      Ecto.NoResultsError -> {:error, :user_not_found}
      ArgumentError -> {:error, :user_not_found}
    end
  end

  defp can_access_conversation?(%DirectConversation{user1_id: user_id}, user_id), do: true
  defp can_access_conversation?(%DirectConversation{user2_id: user_id}, user_id), do: true
  defp can_access_conversation?(_conversation, _user_id), do: false

  defp serialize_conversation(%DirectConversation{} = conversation, current_user_id) do
    other_user = DirectConversation.other_user_struct(conversation, current_user_id)
    is_archived = DirectConversation.archived_for_user?(conversation, current_user_id)

    %{
      id: conversation.id,
      other_user: serialize_user(other_user),
      last_message_at: conversation.last_message_at,
      is_archived: is_archived,
      inserted_at: conversation.inserted_at,
      updated_at: conversation.updated_at
    }
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
      parent_message_id: message.parent_message_id
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
