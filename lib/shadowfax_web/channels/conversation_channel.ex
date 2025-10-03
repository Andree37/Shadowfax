defmodule ShadowfaxWeb.ConversationChannel do
  use ShadowfaxWeb, :channel

  alias Shadowfax.Chat
  alias Shadowfax.Accounts
  alias ShadowfaxWeb.Presence
  alias ShadowfaxWeb.Errors

  @impl true
  def join("conversation:" <> conversation_id, _payload, socket) do
    conversation_id = String.to_integer(conversation_id)
    user_id = socket.assigns.current_user_id

    if Chat.can_access_conversation?(conversation_id, user_id) do
      send(self(), :after_join)
      {:ok, assign(socket, conversation_id: conversation_id)}
    else
      {:error, Errors.ws_error_response(Errors.ws_unauthorized())}
    end
  end

  # Handle broadcasted events
  @impl true
  def handle_info({:new_message, message}, socket) do
    push(socket, "new_message", %{message: serialize_message(message)})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:message_updated, message}, socket) do
    push(socket, "message_updated", %{message: serialize_message(message)})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:message_deleted, message}, socket) do
    push(socket, "message_deleted", %{message: serialize_message(message)})
    {:noreply, socket}
  end

  @impl true
  def handle_info(:after_join, socket) do
    conversation_id = socket.assigns.conversation_id
    user_id = socket.assigns.current_user_id
    user = Accounts.get_user!(user_id)

    # Track user presence
    {:ok, _} =
      Presence.track(socket, user_id, %{
        user_id: user.id,
        username: user.username,
        first_name: user.first_name,
        last_name: user.last_name,
        avatar_url: user.avatar_url,
        status: user.status,
        online_at: DateTime.utc_now() |> DateTime.to_iso8601()
      })

    # Get recent messages
    messages = Chat.list_direct_messages(conversation_id, limit: 50)
    push(socket, "messages_loaded", %{messages: serialize_messages(messages)})

    # Send current presence list to the joining user
    push(socket, "presence_state", Presence.list(socket))

    {:noreply, socket}
  end

  # Incoming Messages
  @impl true
  def handle_in("new_message", %{"content" => content} = payload, socket) do
    conversation_id = socket.assigns.conversation_id
    user_id = socket.assigns.current_user_id

    message_attrs = %{
      content: content,
      user_id: user_id,
      direct_conversation_id: conversation_id,
      message_type: Map.get(payload, "message_type", "text"),
      parent_message_id: Map.get(payload, "parent_message_id"),
      metadata: Map.get(payload, "metadata", %{}),
      attachments: Map.get(payload, "attachments", [])
    }

    case Chat.create_direct_message(message_attrs) do
      {:ok, message} ->
        # Message is automatically broadcast by the Chat context
        {:reply, {:ok, %{message: serialize_message(message)}}, socket}

      {:error, changeset} ->
        {:reply, {:error, %{errors: serialize_errors(changeset)}}, socket}
    end
  end

  @impl true
  def handle_in("edit_message", %{"message_id" => message_id, "content" => content}, socket) do
    user_id = socket.assigns.current_user_id

    try do
      message = Chat.get_message!(message_id)

      if Shadowfax.Chat.Message.can_edit?(message, user_id) do
        case Chat.update_message(message, %{content: content}) do
          {:ok, updated_message} ->
            {:reply, {:ok, %{message: serialize_message(updated_message)}}, socket}

          {:error, changeset} ->
            {:reply, {:error, %{errors: serialize_errors(changeset)}}, socket}
        end
      else
        {:reply, {:error, Errors.ws_error_response(Errors.ws_unauthorized())}, socket}
      end
    rescue
      Ecto.NoResultsError ->
        {:reply, {:error, Errors.ws_error_response(Errors.ws_message_not_found())}, socket}
    end
  end

  @impl true
  def handle_in("delete_message", %{"message_id" => message_id}, socket) do
    user_id = socket.assigns.current_user_id

    try do
      message = Chat.get_message!(message_id)

      if Shadowfax.Chat.Message.can_delete?(message, user_id) do
        case Chat.delete_message(message) do
          {:ok, deleted_message} ->
            {:reply, {:ok, %{message: serialize_message(deleted_message)}}, socket}

          {:error, changeset} ->
            {:reply, {:error, %{errors: serialize_errors(changeset)}}, socket}
        end
      else
        {:reply, {:error, Errors.ws_error_response(Errors.ws_unauthorized())}, socket}
      end
    rescue
      Ecto.NoResultsError ->
        {:reply, {:error, Errors.ws_error_response(Errors.ws_message_not_found())}, socket}
    end
  end

  @impl true
  def handle_in("typing", %{"typing" => typing}, socket) do
    user_id = socket.assigns.current_user_id
    user = Accounts.get_user!(user_id)

    broadcast_from!(socket, "user_typing", %{
      user: serialize_user(user),
      typing: typing,
      timestamp: DateTime.utc_now()
    })

    {:noreply, socket}
  end

  @impl true
  def handle_in("mark_as_read", _payload, socket) do
    # For direct conversations, we don't have a membership table
    # We could create a separate read receipts table or handle this differently
    # For now, we'll just acknowledge the request
    {:reply, {:ok, %{}}, socket}
  end

  @impl true
  def handle_in("load_more_messages", %{"before_message_id" => before_id}, socket) do
    conversation_id = socket.assigns.conversation_id

    # Get messages before the specified message
    messages = Chat.list_direct_messages(conversation_id, limit: 25, offset: before_id)

    {:reply, {:ok, %{messages: serialize_messages(messages)}}, socket}
  end

  @impl true
  def handle_in("get_thread", %{"message_id" => message_id}, socket) do
    try do
      thread_messages = Chat.list_thread_messages(message_id)
      parent_message = Chat.get_message!(message_id)

      {:reply,
       {:ok,
        %{
          parent_message: serialize_message(parent_message),
          thread_messages: serialize_messages(thread_messages)
        }}, socket}
    rescue
      Ecto.NoResultsError ->
        {:reply, {:error, Errors.ws_error_response(Errors.ws_message_not_found())}, socket}
    end
  end

  @impl true
  def handle_in("archive_conversation", %{"is_archived" => is_archived}, socket) do
    conversation_id = socket.assigns.conversation_id
    user_id = socket.assigns.current_user_id

    try do
      conversation = Chat.get_direct_conversation!(conversation_id)

      case Chat.archive_conversation_for_user(conversation, user_id, is_archived) do
        {:ok, _updated_conversation} ->
          {:reply, {:ok, %{archived: is_archived}}, socket}

        {:error, changeset} ->
          {:reply, {:error, %{errors: serialize_errors(changeset)}}, socket}
      end
    rescue
      Ecto.NoResultsError ->
        {:reply, {:error, Errors.ws_error_response(Errors.ws_conversation_not_found())}, socket}
    end
  end

  @impl true
  def terminate(_reason, _socket) do
    # Presence tracking is automatically stopped when the socket disconnects
    :ok
  end

  # Helper functions for serialization
  defp serialize_message(%Shadowfax.Chat.Message{} = message) do
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
      reply_count: if(Ecto.assoc_loaded?(message.replies), do: length(message.replies), else: 0)
    }
  end

  defp serialize_messages(messages) do
    Enum.map(messages, &serialize_message/1)
  end

  defp serialize_user(%Shadowfax.Accounts.User{} = user) do
    %{
      id: user.id,
      username: user.username,
      first_name: user.first_name,
      last_name: user.last_name,
      avatar_url: user.avatar_url,
      status: user.status,
      display_name: Shadowfax.Accounts.User.display_name(user)
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
