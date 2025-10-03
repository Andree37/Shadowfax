defmodule ShadowfaxWeb.AuthController do
  use ShadowfaxWeb, :controller

  alias Shadowfax.Accounts
  alias Shadowfax.Accounts.User

  @doc """
  Register a new user
  """
  def register(conn, %{"user" => user_params}) do
    case Accounts.create_user(user_params) do
      {:ok, user} ->
        token = generate_token(user)

        conn
        |> put_status(:created)
        |> json(%{
          success: true,
          data: %{
            user: serialize_user(user),
            token: token
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
  end

  def register(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{
      success: false,
      error: "Invalid request format. Expected 'user' parameter."
    })
  end

  @doc """
  Login user
  """
  def login(conn, %{"email" => email, "password" => password}) do
    case Accounts.get_user_by_email_and_password(email, password) do
      %User{} = user ->
        token = generate_token(user)

        conn
        |> json(%{
          success: true,
          data: %{
            user: serialize_user(user),
            token: token
          }
        })

      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{
          success: false,
          error: "Invalid email or password"
        })
    end
  end

  def login(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{
      success: false,
      error: "Email and password are required"
    })
  end

  @doc """
  Logout user
  """
  def logout(conn, _params) do
    case get_current_user(conn) do
      %User{} = _user ->
        conn
        |> json(%{
          success: true,
          message: "Successfully logged out"
        })

      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{
          success: false,
          error: "Not authenticated"
        })
    end
  end

  @doc """
  Get current user info
  """
  def me(conn, _params) do
    case get_current_user(conn) do
      %User{} = user ->
        conn
        |> json(%{
          success: true,
          data: %{
            user: serialize_user(user)
          }
        })

      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{
          success: false,
          error: "Not authenticated"
        })
    end
  end

  @doc """
  Verify token validity
  """
  def verify_token(conn, _params) do
    case get_current_user(conn) do
      %User{} = user ->
        conn
        |> json(%{
          success: true,
          data: %{
            user: serialize_user(user),
            valid: true
          }
        })

      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{
          success: false,
          error: "Invalid or expired token",
          valid: false
        })
    end
  end

  # Private functions

  defp get_current_user(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        case verify_token(token) do
          {:ok, user_id} -> Accounts.get_user!(user_id)
          {:error, _reason} -> nil
        end

      _ ->
        nil
    end
  rescue
    Ecto.NoResultsError -> nil
  end

  defp generate_token(user) do
    Phoenix.Token.sign(ShadowfaxWeb.Endpoint, "user auth", user.id)
  end

  defp verify_token(token) do
    # max_age: 1209600 is equivalent to two weeks in seconds
    Phoenix.Token.verify(ShadowfaxWeb.Endpoint, "user auth", token, max_age: 1_209_600)
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
