defmodule ShadowfaxWeb.ChannelController do
  use ShadowfaxWeb, :controller

  alias Shadowfax.Chat
  alias Shadowfax.Chat.Channel
  alias Shadowfax.Accounts.User

  @doc """
  List channels - public channels for all users, user's joined channels if authenticated
  """
  def index(conn, params) do
    {:ok, user} = get_current_user(conn)

    channels =
      case params do
        %{"type" => "joined"} -> Chat.list_user_channels(user.id)
        %{"type" => "public"} -> Chat.list_public_channels()
        _ -> Chat.list_user_channels(user.id) ++ Chat.list_public_channels()
      end

    conn
    |> json(%{
      success: true,
      data: %{
        channels: Enum.map(channels, &serialize_channel/1)
      }
    })
  end

  @doc """
  Create a new channel
  """
  def create(conn, %{"channel" => channel_params}) do
    with {:ok, user} <- get_current_user(conn),
         channel_attrs <- Map.put(channel_params, "created_by_id", user.id),
         {:ok, channel} <- Chat.create_channel(channel_attrs) do
      conn
      |> put_status(:created)
      |> json(%{
        success: true,
        data: %{
          channel: serialize_channel(channel)
        }
      })
    else
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
      error: "Invalid request format. Expected 'channel' parameter."
    })
  end

  @doc """
  Show a specific channel
  """
  def show(conn, %{"id" => id}) do
    with {:ok, user} <- get_current_user(conn),
         channel <- Chat.get_channel!(id),
         true <- can_access_channel?(channel, user.id) do
      membership = Chat.get_channel_membership(channel.id, user.id)

      conn
      |> json(%{
        success: true,
        data: %{
          channel: serialize_channel_with_membership(channel, membership)
        }
      })
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> json(%{
          success: false,
          error: "Access denied. Channel is private."
        })
    end
  rescue
    Ecto.NoResultsError ->
      conn
      |> put_status(:not_found)
      |> json(%{
        success: false,
        error: "Channel not found"
      })
  end

  @doc """
  Update a channel
  """
  def update(conn, %{"id" => id} = params) do
    with {:ok, user} <- get_current_user(conn),
         channel <- Chat.get_channel!(id),
         true <- can_moderate_channel?(channel, user.id),
         {:ok, updated_channel} <- Chat.update_channel(channel, params) do
      conn
      |> json(%{
        success: true,
        data: %{
          channel: serialize_channel(updated_channel)
        }
      })
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> json(%{
          success: false,
          error: "Access denied. Admin or owner privileges required."
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
        error: "Channel not found"
      })
  end

  @doc """
  Delete/Archive a channel
  """
  def delete(conn, %{"id" => id}) do
    with {:ok, user} <- get_current_user(conn),
         channel <- Chat.get_channel!(id),
         true <- can_moderate_channel?(channel, user.id),
         {:ok, archived_channel} <- Chat.archive_channel(channel, true) do
      conn
      |> json(%{
        success: true,
        data: %{
          channel: serialize_channel(archived_channel)
        }
      })
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> json(%{
          success: false,
          error: "Access denied. Admin or owner privileges required."
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
        error: "Channel not found"
      })
  end

  @doc """
  Join a channel
  """
  def join(conn, %{"id" => id} = params) do
    with {:ok, user} <- get_current_user(conn),
         channel <- Chat.get_channel!(id),
         false <- Channel.is_member?(channel, user.id),
         true <- can_join_channel?(channel, user.id, params) do
      case Chat.add_user_to_channel(channel.id, user.id) do
        {:ok, membership} ->
          # Create system message
          Chat.create_system_message(%{
            content: "#{user.username} joined the channel",
            channel_id: channel.id,
            metadata: %{action: "user_joined", user_id: user.id}
          })

          conn
          |> json(%{
            success: true,
            data: %{
              channel: serialize_channel(channel),
              membership: serialize_membership(membership)
            }
          })

        {:error, changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{
            success: false,
            errors: serialize_errors(changeset)
          })
      end
    else
      true ->
        conn
        |> put_status(:conflict)
        |> json(%{
          success: false,
          error: "You are already a member of this channel"
        })

      false ->
        conn
        |> put_status(:forbidden)
        |> json(%{
          success: false,
          error: "Cannot join this channel. Check if it's private or at capacity."
        })
    end
  rescue
    Ecto.NoResultsError ->
      conn
      |> put_status(:not_found)
      |> json(%{
        success: false,
        error: "Channel not found"
      })
  end

  @doc """
  Leave a channel
  """
  def leave(conn, %{"id" => id}) do
    with {:ok, user} <- get_current_user(conn),
         channel <- Chat.get_channel!(id),
         true <- Channel.is_member?(channel, user.id),
         {:ok, _membership} <- Chat.remove_user_from_channel(channel.id, user.id) do
      # Create system message
      Chat.create_system_message(%{
        content: "#{user.username} left the channel",
        channel_id: channel.id,
        metadata: %{action: "user_left", user_id: user.id}
      })

      conn
      |> json(%{
        success: true,
        message: "Successfully left the channel"
      })
    else
      false ->
        conn
        |> put_status(:conflict)
        |> json(%{
          success: false,
          error: "You are not a member of this channel"
        })

      {:error, :not_found} ->
        conn
        |> put_status(:conflict)
        |> json(%{
          success: false,
          error: "You are not a member of this channel"
        })
    end
  rescue
    Ecto.NoResultsError ->
      conn
      |> put_status(:not_found)
      |> json(%{
        success: false,
        error: "Channel not found"
      })
  end

  @doc """
  Get channel members
  """
  def members(conn, %{"id" => id}) do
    with {:ok, user} <- get_current_user(conn),
         channel <- Chat.get_channel!(id),
         true <- can_access_channel?(channel, user.id) do
      members = Chat.list_channel_members(channel.id)

      conn
      |> json(%{
        success: true,
        data: %{
          members: Enum.map(members, &serialize_membership/1),
          total_count: length(members)
        }
      })
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> json(%{
          success: false,
          error: "Access denied. Channel is private."
        })
    end
  rescue
    Ecto.NoResultsError ->
      conn
      |> put_status(:not_found)
      |> json(%{
        success: false,
        error: "Channel not found"
      })
  end

  @doc """
  Get channel messages
  """
  def messages(conn, %{"id" => id} = params) do
    with {:ok, user} <- get_current_user(conn),
         channel <- Chat.get_channel!(id),
         true <- can_access_channel?(channel, user.id) do
      limit = min(String.to_integer(params["limit"] || "50"), 100)
      offset = String.to_integer(params["offset"] || "0")

      messages = Chat.list_channel_messages(channel.id, limit: limit, offset: offset)

      conn
      |> json(%{
        success: true,
        data: %{
          messages: Enum.map(messages, &serialize_message/1),
          channel: serialize_channel(channel)
        }
      })
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> json(%{
          success: false,
          error: "Access denied. Channel is private."
        })
    end
  rescue
    Ecto.NoResultsError ->
      conn
      |> put_status(:not_found)
      |> json(%{
        success: false,
        error: "Channel not found"
      })

    ArgumentError ->
      conn
      |> put_status(:bad_request)
      |> json(%{
        success: false,
        error: "Invalid limit or offset parameter"
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

  defp can_moderate_channel?(%Channel{} = channel, user_id) do
    Channel.user_can_moderate?(channel, user_id)
  end

  defp can_join_channel?(%Channel{is_private: true} = channel, user_id, params) do
    invite_code = Map.get(params, "invite_code")

    cond do
      invite_code && channel.invite_code == invite_code -> true
      Channel.is_member?(channel, user_id) -> false
      true -> false
    end
  end

  defp can_join_channel?(%Channel{} = channel, user_id, _params) do
    Channel.can_join?(channel, user_id)
  end

  defp serialize_channel(%Channel{} = channel) do
    %{
      id: channel.id,
      name: channel.name,
      description: channel.description,
      topic: channel.topic,
      is_private: channel.is_private,
      is_archived: channel.is_archived,
      created_by_id: channel.created_by_id,
      max_members: channel.max_members,
      member_count: Channel.get_member_count(channel),
      display_name: Channel.display_name(channel),
      inserted_at: channel.inserted_at,
      updated_at: channel.updated_at
    }
  end

  defp serialize_channel_with_membership(%Channel{} = channel, membership) do
    channel_data = serialize_channel(channel)

    membership_data =
      if membership do
        %{
          role: membership.role,
          joined_at: membership.joined_at,
          is_muted: membership.is_muted,
          notification_preference: membership.notification_preference,
          # This could be calculated if needed
          unread_count: 0
        }
      else
        nil
      end

    Map.put(channel_data, :membership, membership_data)
  end

  defp serialize_membership(membership) do
    %{
      id: membership.id,
      user_id: membership.user_id,
      channel_id: membership.channel_id,
      role: membership.role,
      joined_at: membership.joined_at,
      is_muted: membership.is_muted,
      notification_preference: membership.notification_preference,
      user: serialize_user(membership.user)
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
