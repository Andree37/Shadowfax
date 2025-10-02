defmodule ShadowfaxWeb.UserController do
  use ShadowfaxWeb, :controller

  alias Shadowfax.Accounts
  alias Shadowfax.Accounts.User

  @doc """
  List all users with optional filters
  """
  def index(conn, params) do
    users =
      case params do
        %{"online" => "true"} -> Accounts.list_online_users()
        _ -> Accounts.list_users()
      end

    conn
    |> json(%{
      success: true,
      data: %{
        users: Enum.map(users, &serialize_user/1)
      }
    })
  end

  @doc """
  Get a specific user by ID
  """
  def show(conn, %{"id" => id}) do
    try do
      user = Accounts.get_user!(id)

      conn
      |> json(%{
        success: true,
        data: %{
          user: serialize_user(user)
        }
      })
    rescue
      Ecto.NoResultsError ->
        conn
        |> put_status(:not_found)
        |> json(%{
          success: false,
          error: "User not found"
        })
    end
  end

  @doc """
  Update user profile
  """
  def update(conn, %{"id" => id} = params) do
    with {:ok, current_user} <- get_current_user(conn),
         true <- can_update_user?(current_user, id),
         user <- Accounts.get_user!(id),
         {:ok, updated_user} <- Accounts.update_user(user, params) do
      conn
      |> json(%{
        success: true,
        data: %{
          user: serialize_user(updated_user)
        }
      })
    else
      {:error, :unauthorized} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{
          success: false,
          error: "Not authenticated"
        })

      false ->
        conn
        |> put_status(:forbidden)
        |> json(%{
          success: false,
          error: "You can only update your own profile"
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
        error: "User not found"
      })
  end

  @doc """
  Search users by username or email
  """
  def search(conn, %{"q" => query}) when is_binary(query) and byte_size(query) > 0 do
    users = Accounts.search_users(query)

    conn
    |> json(%{
      success: true,
      data: %{
        users: Enum.map(users, &serialize_user/1),
        query: query
      }
    })
  end

  def search(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{
      success: false,
      error: "Search query 'q' parameter is required and cannot be empty"
    })
  end

  @doc """
  Update user status (online, away, busy, offline)
  """
  def update_status(conn, %{"status" => status} = params) do
    with {:ok, user} <- get_current_user(conn),
         is_online <- Map.get(params, "is_online", user.is_online),
         {:ok, updated_user} <-
           Accounts.update_user_status(user, %{status: status, is_online: is_online}) do
      conn
      |> json(%{
        success: true,
        data: %{
          user: serialize_user(updated_user)
        }
      })
    else
      {:error, :unauthorized} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{
          success: false,
          error: "Not authenticated"
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

  @doc """
  Get user statistics
  """
  def stats(conn, _params) do
    stats = Accounts.get_user_stats()

    conn
    |> json(%{
      success: true,
      data: stats
    })
  end

  # Private functions

  defp get_current_user(conn) do
    # The authentication plug ensures current_user is always present
    {:ok, conn.assigns.current_user}
  end

  defp can_update_user?(%User{id: user_id}, target_id) do
    user_id == String.to_integer(target_id)
  rescue
    ArgumentError -> false
  end

  defp serialize_user(%User{} = user) do
    %{
      id: user.id,
      username: user.username,
      email: user.email,
      first_name: user.first_name,
      last_name: user.last_name,
      avatar_url: user.avatar_url,
      status: user.status,
      is_online: user.is_online,
      last_seen_at: user.last_seen_at,
      display_name: User.display_name(user),
      inserted_at: user.inserted_at,
      updated_at: user.updated_at
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
